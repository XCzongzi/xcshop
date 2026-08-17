#include "MinecraftAssetImporter.h"

#include <QDir>
#include <QDirIterator>
#include <QFuture>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QMatrix4x4>
#include <QPainter>
#include <QProcess>
#include <QTransform>
#include <QtMath>
#include <QUrl>
#include <QVector3D>
#include <QPointer>
#include <QtConcurrent/QtConcurrentRun>
#include <algorithm>
#include <array>
#include <limits>
#include <functional>

namespace {

QString localPath(const QString &path)
{
    const QUrl url(path);
    return url.isLocalFile() ? url.toLocalFile() : path;
}

QJsonObject jsonObject(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    return document.isObject() ? document.object() : QJsonObject{};
}

QString modelPath(const QString &assetsRoot, QString model)
{
    if (model.startsWith("minecraft:"))
        model.remove(0, QStringLiteral("minecraft:").size());
    if (model.isEmpty())
        return {};
    return assetsRoot + "/models/" + model + ".json";
}

QJsonObject resolvedModel(const QString &assetsRoot, const QString &model, int depth = 0)
{
    if (depth > 12)
        return {};
    const QJsonObject own = jsonObject(modelPath(assetsRoot, model));
    if (own.isEmpty())
        return {};

    QJsonObject result;
    const QString parent = own.value("parent").toString();
    if (!parent.isEmpty())
        result = resolvedModel(assetsRoot, parent, depth + 1);

    QJsonObject inheritedTextures = result.value("textures").toObject();
    const QJsonObject ownTextures = own.value("textures").toObject();
    for (auto it = ownTextures.begin(); it != ownTextures.end(); ++it)
        inheritedTextures.insert(it.key(), it.value());
    result.insert("textures", inheritedTextures);
    QJsonObject inheritedDisplay = result.value("display").toObject();
    const QJsonObject ownDisplay = own.value("display").toObject();
    for (auto displayIt = ownDisplay.begin(); displayIt != ownDisplay.end(); ++displayIt) {
        QJsonObject inheritedContext = inheritedDisplay.value(displayIt.key()).toObject();
        const QJsonObject ownContext = displayIt.value().toObject();
        for (auto contextIt = ownContext.begin(); contextIt != ownContext.end(); ++contextIt)
            inheritedContext.insert(contextIt.key(), contextIt.value());
        inheritedDisplay.insert(displayIt.key(), inheritedContext);
    }
    if (!inheritedDisplay.isEmpty())
        result.insert("display", inheritedDisplay);
    for (auto it = own.begin(); it != own.end(); ++it) {
        if (it.key() != "parent" && it.key() != "textures" && it.key() != "display")
            result.insert(it.key(), it.value());
    }
    return result;
}

QString resolveTexture(const QJsonObject &textures, QString reference)
{
    for (int depth = 0; depth < 12 && reference.startsWith('#'); ++depth) {
        const QJsonValue definition = textures.value(reference.mid(1));
        if (definition.isString())
            reference = definition.toString();
        else if (definition.isObject())
            reference = definition.toObject().value("sprite").toString();
        else
            reference.clear();
    }
    if (reference.startsWith("minecraft:"))
        reference.remove(0, QStringLiteral("minecraft:").size());
    return reference;
}

QString imageForTexture(const QString &assetsRoot, const QString &texture)
{
    if (texture.isEmpty())
        return {};
    const QString candidate = assetsRoot + "/textures/" + texture + ".png";
    return QFileInfo(candidate).isFile() ? candidate : QString{};
}

QString textureValue(const QJsonObject &textures, const QStringList &keys)
{
    for (const QString &key : keys) {
        const QString value = resolveTexture(textures, textures.value(key).toString());
        if (!value.isEmpty())
            return value;
    }
    for (auto it = textures.begin(); it != textures.end(); ++it) {
        const QString value = resolveTexture(textures, it.value().toString());
        if (!value.isEmpty())
            return value;
    }
    return {};
}

QString firstTexture(const QString &directory, const QString &name)
{
    const QString exact = directory + "/" + name + ".png";
    if (QFileInfo(exact).isFile())
        return exact;
    QDir dir(directory);
    const QStringList matches = dir.entryList({name + "_*.png"}, QDir::Files, QDir::Name);
    return matches.isEmpty() ? QString{} : dir.filePath(matches.first());
}

QImage shaded(const QImage &source, qreal factor)
{
    QImage image = source.convertToFormat(QImage::Format_ARGB32);
    for (int y = 0; y < image.height(); ++y) {
        QRgb *pixels = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < image.width(); ++x)
            pixels[x] = qRgba(qRound(qRed(pixels[x]) * factor), qRound(qGreen(pixels[x]) * factor),
                              qRound(qBlue(pixels[x]) * factor), qAlpha(pixels[x]));
    }
    return image;
}

void drawFace(QPainter &painter, const QImage &image, const QPointF &origin,
              const QPointF &xAxis, const QPointF &yAxis)
{
    const qreal width = image.width();
    const qreal height = image.height();
    const QTransform transform(xAxis.x() / width, xAxis.y() / width, 0,
                               yAxis.x() / height, yAxis.y() / height, 0,
                               origin.x(), origin.y(), 1);
    painter.save();
    painter.setTransform(transform);
    painter.drawImage(QPointF(0, 0), image);
    painter.restore();
}

QVector3D vectorFromJson(const QJsonValue &value)
{
    const QJsonArray values = value.toArray();
    if (values.size() != 3)
        return {};
    return {float(values.at(0).toDouble()), float(values.at(1).toDouble()), float(values.at(2).toDouble())};
}

QPointF projectPoint(const QVector3D &point)
{
    // Vanilla renders GUI models with an orthographic camera after applying
    // the model's display.gui transform.
    return {32.0 + (point.x() - 8.0) * 4.10, 32.0 - (point.y() - 8.0) * 4.10};
}

QVector3D displayVector(const QJsonObject &display, const QString &key, const QVector3D &fallback)
{
    const QJsonArray values = display.value(key).toArray();
    return values.size() == 3 ? vectorFromJson(display.value(key)) : fallback;
}

QMatrix4x4 guiTransform(const QJsonObject &model)
{
    const QJsonObject gui = model.value("display").toObject().value("gui").toObject();
    const QVector3D rotation = displayVector(gui, "rotation", {30, 225, 0});
    const QVector3D translation = displayVector(gui, "translation", {});
    const QVector3D scale = displayVector(gui, "scale", {0.625f, 0.625f, 0.625f});

    QMatrix4x4 transform;
    transform.translate(8, 8, 8);
    transform.translate(translation.x() / 16.0f, translation.y() / 16.0f, translation.z() / 16.0f);
    // QMatrix4x4 post-multiplies transforms.  Build the matrix in the reverse
    // call order so Minecraft's rotation [x, y, z] is applied as Y then X for
    // the standard GUI transform (its Z rotation is normally zero).
    transform.rotate(rotation.x(), 1, 0, 0);
    transform.rotate(rotation.y(), 0, 1, 0);
    transform.rotate(rotation.z(), 0, 0, 1);
    transform.scale(scale);
    transform.translate(-8, -8, -8);
    return transform;
}

QJsonArray defaultFaceUv(const QString &direction, const QVector3D &from, const QVector3D &to)
{
    if (direction == "down") return {from.x(), 16 - to.z(), to.x(), 16 - from.z()};
    if (direction == "up") return {from.x(), from.z(), to.x(), to.z()};
    if (direction == "north") return {16 - to.x(), 16 - to.y(), 16 - from.x(), 16 - from.y()};
    if (direction == "south") return {from.x(), 16 - to.y(), to.x(), 16 - from.y()};
    if (direction == "west") return {from.z(), 16 - to.y(), to.z(), 16 - from.y()};
    return {16 - to.z(), 16 - to.y(), 16 - from.z(), 16 - from.y()};
}

QImage faceImage(const QString &assetsRoot, const QJsonObject &textures, const QJsonObject &face,
                 const QString &direction, const QVector3D &from, const QVector3D &to)
{
    QImage image(imageForTexture(assetsRoot, resolveTexture(textures, face.value("texture").toString())));
    if (image.isNull())
        return {};
    // Animated Minecraft textures are stored as a vertical strip of square
    // frames (for example command-block faces are 16x64).  GUI item rendering
    // samples one animation frame, not the complete strip.
    if (image.height() > image.width() && image.height() % image.width() == 0)
        image = image.copy(0, 0, image.width(), image.width());
    const QJsonArray uv = face.contains("uv") ? face.value("uv").toArray() : defaultFaceUv(direction, from, to);
    if (uv.size() == 4) {
        const int left = qBound(0, qRound(uv.at(0).toDouble() / 16.0 * image.width()), image.width());
        const int top = qBound(0, qRound(uv.at(1).toDouble() / 16.0 * image.height()), image.height());
        const int right = qBound(0, qRound(uv.at(2).toDouble() / 16.0 * image.width()), image.width());
        const int bottom = qBound(0, qRound(uv.at(3).toDouble() / 16.0 * image.height()), image.height());
        if (right > left && bottom > top)
            image = image.copy(left, top, right - left, bottom - top);
    }
    const int rotation = face.value("rotation").toInt() % 360;
    if (rotation)
        image = image.transformed(QTransform().rotate(rotation), Qt::FastTransformation);
    // The vertex order for the north, east and west faces runs opposite to
    // Minecraft's UV origin. Mirror those faces so adjoining top/side details
    // (notably the bed pillow) stay on the same end of the model.
    if (direction == "north" || direction == "east" || direction == "west")
        image = image.mirrored(true, false);
    return image;
}

QImage tinted(const QImage &source, const QColor &color)
{
    if (!color.isValid())
        return source;
    QImage image = source.convertToFormat(QImage::Format_ARGB32);
    for (int y = 0; y < image.height(); ++y) {
        QRgb *pixels = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            const QRgb pixel = pixels[x];
            pixels[x] = qRgba(qRed(pixel) * color.red() / 255,
                              qGreen(pixel) * color.green() / 255,
                              qBlue(pixel) * color.blue() / 255,
                              qAlpha(pixel));
        }
    }
    return image;
}

QVector3D faceNormal(const QString &direction)
{
    if (direction == "up") return {0, 1, 0};
    if (direction == "down") return {0, -1, 0};
    if (direction == "north") return {0, 0, -1};
    if (direction == "south") return {0, 0, 1};
    if (direction == "west") return {-1, 0, 0};
    return {1, 0, 0};
}

QVector<QVector3D> faceVertices(const QString &direction, const QVector3D &from, const QVector3D &to)
{
    if (direction == "up") return {{from.x(), to.y(), from.z()}, {to.x(), to.y(), from.z()}, {to.x(), to.y(), to.z()}, {from.x(), to.y(), to.z()}};
    if (direction == "down") return {{from.x(), from.y(), to.z()}, {to.x(), from.y(), to.z()}, {to.x(), from.y(), from.z()}, {from.x(), from.y(), from.z()}};
    if (direction == "north") return {{to.x(), to.y(), from.z()}, {from.x(), to.y(), from.z()}, {from.x(), from.y(), from.z()}, {to.x(), from.y(), from.z()}};
    if (direction == "south") return {{from.x(), to.y(), to.z()}, {to.x(), to.y(), to.z()}, {to.x(), from.y(), to.z()}, {from.x(), from.y(), to.z()}};
    if (direction == "west") return {{from.x(), to.y(), to.z()}, {from.x(), to.y(), from.z()}, {from.x(), from.y(), from.z()}, {from.x(), from.y(), to.z()}};
    return {{to.x(), to.y(), from.z()}, {to.x(), to.y(), to.z()}, {to.x(), from.y(), to.z()}, {to.x(), from.y(), from.z()}};
}

QMatrix4x4 elementTransform(const QJsonObject &element)
{
    const QJsonObject rotation = element.value("rotation").toObject();
    QMatrix4x4 matrix;
    if (rotation.isEmpty())
        return matrix;
    const QVector3D origin = vectorFromJson(rotation.value("origin"));
    const QString axis = rotation.value("axis").toString();
    const QVector3D axisVector = axis == "x" ? QVector3D(1, 0, 0) : axis == "z" ? QVector3D(0, 0, 1) : QVector3D(0, 1, 0);
    matrix.translate(origin);
    matrix.rotate(float(rotation.value("angle").toDouble()), axisVector);
    if (rotation.value("rescale").toBool()) {
        const float cosine = qAbs(qCos(qDegreesToRadians(float(rotation.value("angle").toDouble()))));
        const float rescale = cosine > 0.0001f ? 1.0f / cosine : 1.0f;
        if (axis == "x") matrix.scale(1, rescale, rescale);
        else if (axis == "z") matrix.scale(rescale, rescale, 1);
        else matrix.scale(rescale, 1, rescale);
    }
    matrix.translate(-origin);
    return matrix;
}

bool horizontalSpriteModel(const QJsonArray &elements)
{
    if (elements.isEmpty())
        return false;
    for (const QJsonValue &value : elements) {
        const QJsonObject element = value.toObject();
        const QVector3D from = vectorFromJson(element.value("from"));
        const QVector3D to = vectorFromJson(element.value("to"));
        if (qAbs(to.y() - from.y()) > 0.01f)
            return false;
    }
    return true;
}

bool renderModelIcon(const QString &assetsRoot, const QJsonObject &model, const QString &outputPath,
                     const QColor &tint = {})
{
    const QJsonArray elements = model.value("elements").toArray();
    const QJsonObject textures = model.value("textures").toObject();
    if (elements.isEmpty() || horizontalSpriteModel(elements))
        return false;

    struct Face {
        QImage image;
        std::array<QPointF, 4> points;
        std::array<float, 4> depths;
        qreal shade = 1.0;
    };
    QVector<Face> faces;
    const QVector3D camera(0, 0, 1);
    const QVector3D light = model.value("gui_light").toString() == "front"
        ? QVector3D(0, 0, 1) : QVector3D(-0.35f, 0.7f, 1).normalized();
    const QMatrix4x4 gui = guiTransform(model);
    auto addFace = [&faces, &assetsRoot, &textures, &camera, &light, &tint](const QString &direction, const QJsonObject &face,
                                                                               const QVector<QVector3D> &vertices,
                                                                               const QVector3D &elementFrom, const QVector3D &elementTo,
                                                                               const QMatrix4x4 &transform) {
        QImage image = faceImage(assetsRoot, textures, face, direction, elementFrom, elementTo);
        if (image.isNull())
            return;
        image = tinted(image, tint);
        const QVector3D normal = transform.mapVector(faceNormal(direction)).normalized();
        if (QVector3D::dotProduct(normal, camera) <= 0.001f)
            return;
        const QVector3D p0_3d = transform.map(vertices.at(0));
        const QVector3D p1_3d = transform.map(vertices.at(1));
        const QVector3D p2_3d = transform.map(vertices.at(2));
        const QVector3D p3_3d = transform.map(vertices.at(3));
        const qreal shade = 0.55 + 0.45 * qMax(0.0f, QVector3D::dotProduct(normal, light));
        faces.append({image, {projectPoint(p0_3d), projectPoint(p1_3d), projectPoint(p2_3d), projectPoint(p3_3d)},
                      {QVector3D::dotProduct(p0_3d, camera), QVector3D::dotProduct(p1_3d, camera),
                       QVector3D::dotProduct(p2_3d, camera), QVector3D::dotProduct(p3_3d, camera)}, shade});
    };

    for (const QJsonValue &value : elements) {
        const QJsonObject element = value.toObject();
        const QVector3D from = vectorFromJson(element.value("from"));
        const QVector3D to = vectorFromJson(element.value("to"));
        const QJsonObject modelFaces = element.value("faces").toObject();
        const QMatrix4x4 transform = gui * elementTransform(element);
        for (auto it = modelFaces.begin(); it != modelFaces.end(); ++it)
            addFace(it.key(), it.value().toObject(), faceVertices(it.key(), from, to), from, to, transform);
    }
    if (faces.isEmpty())
        return false;

    QImage icon(64, 64, QImage::Format_ARGB32);
    icon.fill(Qt::transparent);
    QVector<float> depthBuffer(icon.width() * icon.height(), -std::numeric_limits<float>::infinity());
    const auto rasterizeTriangle = [&icon, &depthBuffer](const Face &face, int first, int second, int third) {
        const QPointF a = face.points.at(first);
        const QPointF b = face.points.at(second);
        const QPointF c = face.points.at(third);
        const float area = float((b.x() - a.x()) * (c.y() - a.y()) - (b.y() - a.y()) * (c.x() - a.x()));
        if (qAbs(area) < 0.0001f)
            return;
        const int minX = qMax(0, qFloor(qMin(a.x(), qMin(b.x(), c.x()))));
        const int maxX = qMin(icon.width() - 1, qCeil(qMax(a.x(), qMax(b.x(), c.x()))));
        const int minY = qMax(0, qFloor(qMin(a.y(), qMin(b.y(), c.y()))));
        const int maxY = qMin(icon.height() - 1, qCeil(qMax(a.y(), qMax(b.y(), c.y()))));
        const std::array<float, 4> u{0.0f, float(face.image.width() - 1), float(face.image.width() - 1), 0.0f};
        const std::array<float, 4> v{0.0f, 0.0f, float(face.image.height() - 1), float(face.image.height() - 1)};
        for (int y = minY; y <= maxY; ++y) {
            QRgb *pixels = reinterpret_cast<QRgb *>(icon.scanLine(y));
            for (int x = minX; x <= maxX; ++x) {
                const QPointF point(x + 0.5, y + 0.5);
                const float w0 = float(((b.x() - point.x()) * (c.y() - point.y()) - (b.y() - point.y()) * (c.x() - point.x())) / area);
                const float w1 = float(((c.x() - point.x()) * (a.y() - point.y()) - (c.y() - point.y()) * (a.x() - point.x())) / area);
                const float w2 = 1.0f - w0 - w1;
                if (w0 < -0.0001f || w1 < -0.0001f || w2 < -0.0001f)
                    continue;
                const float depth = w0 * face.depths.at(first) + w1 * face.depths.at(second) + w2 * face.depths.at(third);
                const int pixelIndex = y * icon.width() + x;
                if (depth <= depthBuffer.at(pixelIndex))
                    continue;
                const int sourceX = qBound(0, qRound(w0 * u.at(first) + w1 * u.at(second) + w2 * u.at(third)), face.image.width() - 1);
                const int sourceY = qBound(0, qRound(w0 * v.at(first) + w1 * v.at(second) + w2 * v.at(third)), face.image.height() - 1);
                const QRgb source = face.image.pixel(sourceX, sourceY);
                if (!qAlpha(source))
                    continue;
                depthBuffer[pixelIndex] = depth;
                pixels[x] = qRgba(qRound(qRed(source) * face.shade), qRound(qGreen(source) * face.shade),
                                  qRound(qBlue(source) * face.shade), qAlpha(source));
            }
        }
    };
    for (const Face &face : faces) {
        rasterizeTriangle(face, 0, 1, 2);
        rasterizeTriangle(face, 0, 2, 3);
    }
    return icon.save(outputPath, "PNG");
}

bool renderEntityCubeIcon(const QString &texturePath, const QRect &topRect,
                          const QRect &sideRect, const QString &outputPath)
{
    const QImage texture(texturePath);
    const QImage top = texture.copy(topRect);
    const QImage side = texture.copy(sideRect);
    if (top.isNull() || side.isNull())
        return false;

    QImage icon(64, 64, QImage::Format_ARGB32_Premultiplied);
    icon.fill(Qt::transparent);
    QPainter painter(&icon);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, false);
    drawFace(painter, top, QPointF(32, 4), QPointF(22, 11), QPointF(-20, 11));
    drawFace(painter, shaded(side, 0.78), QPointF(12, 15), QPointF(20, 11), QPointF(0, 27));
    drawFace(painter, shaded(side, 0.60), QPointF(32, 26), QPointF(20, -11), QPointF(0, 27));
    painter.end();
    return icon.save(outputPath, "PNG");
}

bool renderBedIcon(const QString &assetsRoot, const QString &name, const QString &outputPath)
{
    const QJsonObject head = resolvedModel(assetsRoot, "block/" + name + "_head");
    const QJsonObject foot = resolvedModel(assetsRoot, "block/" + name + "_foot");
    if (head.isEmpty() || foot.isEmpty())
        return false;

    QJsonObject combined;
    QJsonObject display = head.value("display").toObject();
    QJsonObject gui = display.value("gui").toObject();
    gui.insert("scale", QJsonArray{0.42, 0.42, 0.42});
    gui.insert("translation", QJsonArray{0.0, 0.0, 0.0});
    display.insert("gui", gui);
    combined.insert("display", display);
    combined.insert("gui_light", head.value("gui_light"));
    QJsonObject textures;
    QJsonArray elements;
    const auto appendPart = [&textures, &elements](const QJsonObject &part, const QString &prefix, float zOffset) {
        const QJsonObject partTextures = part.value("textures").toObject();
        for (auto it = partTextures.begin(); it != partTextures.end(); ++it)
            textures.insert(prefix + it.key(), it.value());
        for (const QJsonValue &value : part.value("elements").toArray()) {
            QJsonObject element = value.toObject();
            for (const QString &bound : {QStringLiteral("from"), QStringLiteral("to")}) {
                QJsonArray point = element.value(bound).toArray();
                if (point.size() == 3) {
                    point[2] = point.at(2).toDouble() + zOffset;
                    element.insert(bound, point);
                }
            }
            QJsonObject faces = element.value("faces").toObject();
            for (auto face = faces.begin(); face != faces.end(); ++face) {
                QJsonObject definition = face.value().toObject();
                const QString texture = definition.value("texture").toString();
                if (texture.startsWith('#'))
                    definition.insert("texture", "#" + prefix + texture.mid(1));
                face.value() = definition;
            }
            element.insert("faces", faces);
            elements.append(element);
        }
    };

    appendPart(head, "head_", 0);
    // The item definition positions the foot one full block behind the head.
    appendPart(foot, "foot_", 15);
    combined.insert("textures", textures);
    combined.insert("elements", elements);
    if (!renderModelIcon(assetsRoot, combined, outputPath))
        return false;

    const QImage rendered(outputPath);
    if (rendered.isNull())
        return false;
    int left = rendered.width();
    int top = rendered.height();
    int right = -1;
    int bottom = -1;
    for (int y = 0; y < rendered.height(); ++y) {
        for (int x = 0; x < rendered.width(); ++x) {
            if (!qAlpha(rendered.pixel(x, y)))
                continue;
            left = qMin(left, x);
            top = qMin(top, y);
            right = qMax(right, x);
            bottom = qMax(bottom, y);
        }
    }
    if (right < left || bottom < top)
        return false;

    QImage centered(rendered.size(), QImage::Format_ARGB32_Premultiplied);
    centered.fill(Qt::transparent);
    QPainter painter(&centered);
    painter.drawImage((centered.width() - (right - left + 1)) / 2 - left,
                      (centered.height() - (bottom - top + 1)) / 2 - top, rendered);
    painter.end();
    return centered.save(outputPath, "PNG");
}

QColor bannerDyeColor(const QString &name)
{
    static const std::array<std::pair<const char *, QRgb>, 16> colors{{
        {"white", 0xfff9fffe}, {"orange", 0xfff9801d}, {"magenta", 0xffc74ebd}, {"light_blue", 0xff3ab3da},
        {"yellow", 0xfffed83d}, {"lime", 0xff80c71f}, {"pink", 0xfff38baa}, {"gray", 0xff474f52},
        {"light_gray", 0xff9d9d97}, {"cyan", 0xff169c9c}, {"purple", 0xff8932b8}, {"blue", 0xff3c44aa},
        {"brown", 0xff835432}, {"green", 0xff5e7c16}, {"red", 0xffb02e26}, {"black", 0xff1d1d21}
    }};
    const QString colorName = name.left(name.size() - QStringLiteral("_banner").size());
    for (const auto &[candidate, color] : colors) {
        if (colorName == QLatin1String(candidate))
            return QColor::fromRgba(color);
    }
    return {};
}

bool renderBannerIcon(const QString &assetsRoot, const QString &name, const QString &outputPath)
{
    const QColor dye = bannerDyeColor(name);
    if (!dye.isValid()
        || !QFileInfo::exists(assetsRoot + "/textures/entity/banner/banner_base.png"))
        return false;

    // This is BannerModel's 20x40x1 flag part, including its entity-texture
    // UVs.  Rendering it through the normal model path gives the same GUI
    // camera, depth test and side shading as vanilla block/item models.
    QJsonObject faces;
    const auto addFace = [&faces](const QString &direction, const QJsonArray &uv) {
        faces.insert(direction, QJsonObject{{"texture", "#banner"}, {"uv", uv}});
    };
    addFace("down", {1, 0, 21, 1});
    addFace("up", {21, 0, 41, 1});
    addFace("west", {0, 1, 1, 41});
    addFace("north", {1, 1, 21, 41});
    addFace("east", {21, 1, 22, 41});
    addFace("south", {22, 1, 42, 41});

    QJsonObject model;
    model.insert("gui_light", "front");
    model.insert("textures", QJsonObject{{"banner", "entity/banner/banner_base"}});
    model.insert("display", QJsonObject{{"gui", QJsonObject{
        {"rotation", QJsonArray{30, 20, 0}},
        {"translation", QJsonArray{0, -3.25, 0}},
        {"scale", QJsonArray{0.355, 0.355, 0.355}}
    }}});
    model.insert("elements", QJsonArray{QJsonObject{
        {"from", QJsonArray{0, -8, 7}},
        {"to", QJsonArray{16, 24, 8}},
        {"faces", faces}
    }});
    return renderModelIcon(assetsRoot, model, outputPath, dye);
}

QJsonObject entityBoxFaces(const QString &textureReference, int textureWidth, int textureHeight,
                           qreal u, qreal v, qreal width, qreal height, qreal depth)
{
    const auto uv = [textureWidth, textureHeight](qreal left, qreal top, qreal right, qreal bottom) {
        return QJsonArray{left * 16.0 / textureWidth, top * 16.0 / textureHeight,
                          right * 16.0 / textureWidth, bottom * 16.0 / textureHeight};
    };
    const auto face = [&textureReference, &uv](const QJsonArray &coordinates) {
        return QJsonObject{{"texture", textureReference}, {"uv", coordinates}};
    };
    // ModelPart unwraps entity texture cubes in this same order.  This keeps
    // the face, side and top pixels of mob skins aligned on the item model.
    const QJsonObject northFace = face(uv(u + depth, v + depth, u + depth + width, v + depth + height));
    const QJsonObject southFace = face(uv(u + depth + width + depth, v + depth,
                                          u + depth + width + depth + width, v + depth + height));
    return QJsonObject{
        {"down", face(uv(u + depth, v, u + depth + width, v + depth))},
        {"up", face(uv(u + depth + width, v, u + depth + 2 * width, v + depth))},
        {"west", face(uv(u, v + depth, u + depth, v + depth + height))},
        // The item GUI camera sees south, while entity models store the face
        // on north, so exchange the two texture faces here.
        {"north", southFace},
        {"east", face(uv(u + depth + width, v + depth, u + depth + width + depth, v + depth + height))},
        {"south", northFace}
    };
}

QString headTextureReference(const QString &name)
{
    if (name == "skeleton_skull") return "entity/skeleton/skeleton";
    if (name == "wither_skeleton_skull") return "entity/skeleton/wither_skeleton";
    if (name == "zombie_head") return "entity/zombie/zombie";
    if (name == "creeper_head") return "entity/creeper/creeper";
    if (name == "piglin_head") return "entity/piglin/piglin";
    if (name == "player_head") return "entity/player/wide/steve";
    return {};
}

bool renderHeadIcon(const QString &assetsRoot, const QString &name, const QString &outputPath)
{
    const QString texture = headTextureReference(name);
    if (texture.isEmpty() || !QFileInfo::exists(assetsRoot + "/textures/" + texture + ".png"))
        return false;
    const int textureHeight = (name == "skeleton_skull" || name == "wither_skeleton_skull"
                               || name == "creeper_head") ? 32 : 64;
    const QJsonObject templateModel = resolvedModel(assetsRoot, "item/template_skull");
    QJsonObject model;
    model.insert("gui_light", "front");
    model.insert("display", templateModel.value("display"));
    model.insert("textures", QJsonObject{{"head", texture}});
    QJsonArray elements{QJsonObject{
        {"from", QJsonArray{4, 4, 4}}, {"to", QJsonArray{12, 12, 12}},
        {"faces", entityBoxFaces("#head", 64, textureHeight, 0, 0, 8, 8, 8)}
    }};
    // Player heads include the hat layer from the default Steve skin.
    if (name == "player_head") {
        elements.append(QJsonObject{
            {"from", QJsonArray{3.75, 3.75, 3.75}}, {"to", QJsonArray{12.25, 12.25, 12.25}},
            {"faces", entityBoxFaces("#head", 64, 64, 32, 0, 8, 8, 8)}
        });
    }
    model.insert("elements", elements);
    return renderModelIcon(assetsRoot, model, outputPath);
}

bool renderTextureCubeIcon(const QString &texturePath, const QString &outputPath, bool chestLatch = false)
{
    const QImage texture(texturePath);
    if (texture.isNull())
        return false;

    qint64 red = 0;
    qint64 green = 0;
    qint64 blue = 0;
    int samples = 0;
    for (int y = 0; y < texture.height(); ++y) {
        for (int x = 0; x < texture.width(); ++x) {
            const QRgb pixel = texture.pixel(x, y);
            if (!qAlpha(pixel))
                continue;
            red += qRed(pixel);
            green += qGreen(pixel);
            blue += qBlue(pixel);
            ++samples;
        }
    }
    const QColor baseColor = samples > 0
        ? QColor(int(red / samples), int(green / samples), int(blue / samples)) : QColor("#777777");
    QImage icon(64, 64, QImage::Format_ARGB32_Premultiplied);
    icon.fill(Qt::transparent);
    QPainter painter(&icon);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, false);
    painter.setPen(Qt::NoPen);
    painter.setBrush(baseColor);
    painter.drawPolygon(QPolygonF{{32, 4}, {54, 15}, {34, 26}, {12, 15}});
    painter.setBrush(baseColor.darker(130));
    painter.drawPolygon(QPolygonF{{12, 15}, {34, 26}, {34, 53}, {12, 42}});
    painter.setBrush(baseColor.darker(165));
    painter.drawPolygon(QPolygonF{{34, 26}, {54, 15}, {54, 42}, {34, 53}});
    drawFace(painter, texture, QPointF(32, 4), QPointF(22, 11), QPointF(-20, 11));
    drawFace(painter, shaded(texture, 0.78), QPointF(12, 15), QPointF(20, 11), QPointF(0, 27));
    drawFace(painter, shaded(texture, 0.60), QPointF(32, 26), QPointF(20, -11), QPointF(0, 27));
    if (chestLatch) {
        painter.setPen(QPen(QColor("#513012"), 1));
        painter.drawLine(QPointF(13, 27), QPointF(33, 38));
        painter.drawLine(QPointF(33, 38), QPointF(53, 27));
        painter.setPen(Qt::NoPen);
        painter.setBrush(QColor("#d4a638"));
        painter.drawRoundedRect(QRectF(29, 34, 7, 8), 1, 1);
    }
    painter.end();
    return icon.save(outputPath, "PNG");
}

QJsonArray chestUv(qreal left, qreal top, qreal right, qreal bottom)
{
    // Entity textures use a 64x64 atlas while block-model UVs use a 16x16 grid.
    return {left / 4.0, top / 4.0, right / 4.0, bottom / 4.0};
}

QJsonObject chestBox(const QJsonArray &from, const QJsonArray &to,
                     qreal u, qreal v, qreal width, qreal height, qreal depth)
{
    QJsonObject faces;
    const auto addFace = [&faces](const QString &direction, const QJsonArray &uv) {
        QJsonObject face;
        face.insert("texture", "#chest");
        face.insert("uv", uv);
        faces.insert(direction, face);
    };
    // Layout used by Minecraft's entity ModelPart cube UV unwrapping.
    // ModelPart lays the upward-facing texture after the downward-facing one
    // in the atlas' top row.
    addFace("down", chestUv(u + depth, v, u + depth + width, v + depth));
    addFace("up", chestUv(u + depth + width, v, u + depth + 2 * width, v + depth));
    addFace("west", chestUv(u, v + depth, u + depth, v + depth + height));
    addFace("north", chestUv(u + depth, v + depth, u + depth + width, v + depth + height));
    addFace("east", chestUv(u + depth + width, v + depth, u + depth + width + depth, v + depth + height));
    addFace("south", chestUv(u + depth + width + depth, v + depth,
                              u + depth + width + depth + width, v + depth + height));
    QJsonObject box;
    box.insert("from", from);
    box.insert("to", to);
    box.insert("faces", faces);
    return box;
}

bool renderChestIcon(const QString &assetsRoot, const QString &textureName, const QString &outputPath)
{
    const QString texturePath = assetsRoot + "/textures/entity/chest/" + textureName + ".png";
    if (!QFileInfo::exists(texturePath))
        return false;

    QJsonObject model;
    model.insert("gui_light", "side");
    model.insert("textures", QJsonObject{{"chest", "entity/chest/" + textureName}});
    // A chest occupies 14/16 of a block on every axis.  Keep its two pieces
    // within that 14x14x14 volume so the icon has the same proportions as in game.
    model.insert("elements", QJsonArray{
        chestBox({1, 11, 1}, {15, 15, 15}, 0, 0, 14, 4, 14),
        chestBox({1, 1, 1}, {15, 11, 15}, 0, 19, 14, 10, 14),
        chestBox({7, 9, 0}, {9, 13, 1}, 0, 0, 2, 4, 1)
    });
    return renderModelIcon(assetsRoot, model, outputPath);
}

QString chestTextureName(const QString &name)
{
    if (name == "chest")
        return "normal";
    if (name == "trapped_chest" || name == "ender_chest")
        return name.left(name.size() - QStringLiteral("_chest").size());
    if (name == "copper_chest")
        return "copper";
    if (name == "waxed_copper_chest")
        return "copper";
    if (name == "exposed_copper_chest")
        return "copper_exposed";
    if (name == "waxed_exposed_copper_chest")
        return "copper_exposed";
    if (name == "weathered_copper_chest")
        return "copper_weathered";
    if (name == "waxed_weathered_copper_chest")
        return "copper_weathered";
    if (name == "oxidized_copper_chest")
        return "copper_oxidized";
    if (name == "waxed_oxidized_copper_chest")
        return "copper_oxidized";
    return {};
}

bool renderSpecialItemIcon(const QString &assetsRoot, const QString &name, const QString &outputPath)
{
    if (renderHeadIcon(assetsRoot, name, outputPath))
        return true;

    if (name.endsWith("_bed"))
        return renderBedIcon(assetsRoot, name, outputPath);

    if (name.endsWith("_banner"))
        return renderBannerIcon(assetsRoot, name, outputPath);

    if (name == "shulker_box" || name.endsWith("_shulker_box")) {
        return renderTextureCubeIcon(assetsRoot + "/textures/block/" + name + ".png", outputPath);
    }

    const QString chestTexture = chestTextureName(name);
    if (!chestTexture.isEmpty())
        return renderChestIcon(assetsRoot, chestTexture, outputPath);
    return false;
}

QString modelReferenceFromItemDefinition(const QJsonValue &definition, int depth = 0)
{
    if (depth > 12 || !definition.isObject())
        return {};
    const QJsonObject object = definition.toObject();
    const QJsonValue model = object.value("model");
    if (model.isString())
        return model.toString();
    if (model.isObject()) {
        const QString nested = modelReferenceFromItemDefinition(model, depth + 1);
        if (!nested.isEmpty())
            return nested;
    }

    // Dynamic definitions are intentionally resolved to their fallback/default state.
    for (const QString &key : {QStringLiteral("fallback"), QStringLiteral("on_false"), QStringLiteral("on_true")}) {
        const QString fallback = modelReferenceFromItemDefinition(object.value(key), depth + 1);
        if (!fallback.isEmpty())
            return fallback;
    }
    for (const QString &key : {QStringLiteral("entries"), QStringLiteral("cases"), QStringLiteral("models")}) {
        const QJsonArray choices = object.value(key).toArray();
        for (const QJsonValue &choice : choices) {
            const QString selected = modelReferenceFromItemDefinition(choice, depth + 1);
            if (!selected.isEmpty())
                return selected;
        }
    }
    return object.value("base").toString();
}

QJsonObject itemRenderModel(const QString &assetsRoot, const QString &name)
{
    const QJsonObject definition = jsonObject(assetsRoot + "/items/" + name + ".json");
    const QString definitionModel = modelReferenceFromItemDefinition(definition);
    if (!definitionModel.isEmpty()) {
        const QJsonObject model = resolvedModel(assetsRoot, definitionModel);
        if (!model.isEmpty())
            return model;
    }

    QJsonObject model = resolvedModel(assetsRoot, "item/" + name);
    if (!model.isEmpty())
        return model;
    model = resolvedModel(assetsRoot, "block/" + name);
    if (!model.isEmpty())
        return model;

    const QJsonObject blockstate = jsonObject(assetsRoot + "/blockstates/" + name + ".json");
    const QJsonObject variants = blockstate.value("variants").toObject();
    QJsonValue variant = variants.value("");
    if (variant.isUndefined() && !variants.isEmpty())
        variant = variants.begin().value();
    if (variant.isArray() && !variant.toArray().isEmpty())
        variant = variant.toArray().at(0);
    const QString blockstateModel = variant.toObject().value("model").toString();
    return blockstateModel.isEmpty() ? QJsonObject{} : resolvedModel(assetsRoot, blockstateModel);
}

QString modelTexturePath(const QString &assetsRoot, const QJsonObject &model)
{
    const QJsonObject textures = model.value("textures").toObject();
    const QString texture = textureValue(textures, {"layer0", "texture", "all", "top", "side", "particle"});
    return imageForTexture(assetsRoot, texture);
}

QString itemId(const QJsonObject &entry)
{
    const QString value = entry.value("name").toString();
    return value.startsWith("minecraft:") ? value.mid(QStringLiteral("minecraft:").size()) : QString{};
}

} // namespace

QVariantMap importGameJarImpl(const QString &jarPath, const QString &itemsRootPath,
                              const std::function<void(int, const QString &)> &progress)
{
    QVariantMap result{{"ok", false}, {"message", "导入失败"}, {"extracted", 0}, {"generated", 0}, {"copied", 0}, {"skipped", 0}};
    progress(1, "正在检查游戏文件…");
    const QString jar = localPath(jarPath);
    const QString itemsRoot = localPath(itemsRootPath);
    if (!QFileInfo(jar).isFile() || !jar.endsWith(".jar", Qt::CaseInsensitive)) {
        result["message"] = "请选择有效的 Minecraft 游戏 .jar 文件。";
        return result;
    }

    const QString tempRoot = itemsRoot + "/temp";
    const QString assetsRoot = tempRoot + "/assets/minecraft";
    const QString outputRoot = itemsRoot + "/assets/minecraft";
    QDir temp(tempRoot);
    progress(4, "正在清理临时资源目录…");
    if (temp.exists() && !temp.removeRecursively()) {
        result["message"] = "无法清理临时资源目录。";
        return result;
    }
    if (!QDir().mkpath(tempRoot) || !QDir().mkpath(outputRoot)) {
        result["message"] = "无法创建物品资源目录。";
        return result;
    }

    progress(8, "正在统计游戏资源…");
    QProcess lister;
    lister.start("tar", {"-tf", jar, "assets/minecraft"});
    if (!lister.waitForStarted(3000) || !lister.waitForFinished(30000) || lister.exitCode() != 0) {
        result["message"] = "无法读取游戏 .jar。请确认系统可使用 tar.exe，且文件没有损坏。";
        return result;
    }
    const int archiveEntries = qMax(1, lister.readAllStandardOutput().count('\n'));

    progress(9, "正在从游戏 .jar 提取 assets/minecraft…");
    QProcess extractor;
    extractor.setWorkingDirectory(tempRoot);
    extractor.start("tar", {"-xvf", jar, "assets/minecraft"});
    if (!extractor.waitForStarted(3000)) {
        result["message"] = "无法解压游戏 .jar。请确认系统可使用 tar.exe，且文件没有损坏。";
        return result;
    }
    int extractedEntries = 0;
    while (extractor.state() != QProcess::NotRunning) {
        extractor.waitForReadyRead(120);
        extractedEntries += extractor.readAllStandardOutput().count('\n');
        progress(9 + qMin(17, extractedEntries * 17 / archiveEntries),
                 QString("正在从游戏 .jar 提取资源：%1 / %2").arg(extractedEntries).arg(archiveEntries));
    }
    extractedEntries += extractor.readAllStandardOutput().count('\n');
    if (extractor.exitCode() != 0) {
        result["message"] = "无法解压游戏 .jar。请确认系统可使用 tar.exe，且文件没有损坏。";
        return result;
    }
    if (!QDir(assetsRoot).exists()) {
        result["message"] = "该 .jar 不包含 assets/minecraft，可能不是客户端游戏文件。";
        return result;
    }

    int extracted = 0;
    QDirIterator extractedFiles(assetsRoot, QDir::Files, QDirIterator::Subdirectories);
    while (extractedFiles.hasNext()) {
        extractedFiles.next();
        ++extracted;
    }
    result["extracted"] = extracted;
    progress(28, QString("已提取 %1 个资源文件，正在读取物品映射表…").arg(extracted));

    QFile mappingFile(itemsRoot + "/items.json");
    if (!mappingFile.open(QIODevice::ReadOnly)) {
        result["message"] = "资源已解压，但无法读取 items.json 映射表。";
        return result;
    }
    const QJsonDocument mapping = QJsonDocument::fromJson(mappingFile.readAll());
    if (!mapping.isArray()) {
        result["message"] = "资源已解压，但 items.json 映射表格式无效。";
        return result;
    }

    int generated = 0;
    int copied = 0;
    int skipped = 0;
    const QString itemTextureDir = assetsRoot + "/textures/item";
    const QJsonArray entries = mapping.array();
    for (int index = 0; index < entries.size(); ++index) {
        if (index % 10 == 0)
            progress(30 + index * 69 / qMax(1, entries.size()),
                     QString("正在生成物品图标：%1 / %2").arg(index).arg(entries.size()));
        const QJsonValue &value = entries.at(index);
        const QString name = itemId(value.toObject());
        if (name.isEmpty() || name == "air")
            continue;
        const QString outputPath = outputRoot + "/" + name + ".png";
        QFile::remove(outputPath);
        // DragonHeadModel is a special entity model rather than a block-model
        // item.  Use the curated local icon shipped with xcshop so importing
        // a game JAR never routes it through the generic model renderer.
        if (name == "dragon_head") {
            const QString localDragonIcon = QDir(itemsRoot).absoluteFilePath("../dragon_head.png");
            if (QFileInfo(localDragonIcon).isFile() && QFile::copy(localDragonIcon, outputPath)) {
                ++copied;
                continue;
            }
        }
        if (renderSpecialItemIcon(assetsRoot, name, outputPath)) {
            ++generated;
            continue;
        }
        const QJsonObject model = itemRenderModel(assetsRoot, name);
        if (!model.isEmpty()) {
            if (renderModelIcon(assetsRoot, model, outputPath)) {
                ++generated;
                continue;
            }
            const QString modelTexture = modelTexturePath(assetsRoot, model);
            if (!modelTexture.isEmpty() && QFile::copy(modelTexture, outputPath)) {
                ++copied;
                continue;
            }
        }

        QString source = firstTexture(itemTextureDir, name);
        if (source.isEmpty() && name.endsWith("_spawn_egg"))
            source = firstTexture(itemTextureDir, "spawn_egg");
        if (!source.isEmpty()) {
            QFile::remove(outputPath);
            if (QFile::copy(source, outputPath)) {
                ++copied;
                continue;
            }
        }
        ++skipped;
    }

    result["ok"] = true;
    result["generated"] = generated;
    result["copied"] = copied;
    result["skipped"] = skipped;
    result["message"] = QString("已解压 %1 个资源文件；生成 %2 个方块图标，复制 %3 个物品图标，%4 项未找到贴图。")
        .arg(extracted).arg(generated).arg(copied).arg(skipped);
    progress(100, result["message"].toString());
    return result;
}

bool MinecraftAssetImporter::importing() const
{
    return m_importing;
}

void MinecraftAssetImporter::startImportGameJar(const QString &jarPath, const QString &itemsRootPath)
{
    if (m_importing)
        return;

    m_importing = true;
    emit importingChanged();
    m_watcher = new QFutureWatcher<QVariantMap>(this);
    connect(m_watcher, &QFutureWatcher<QVariantMap>::finished, this, [this] {
        const QVariantMap report = m_watcher->result();
        m_watcher->deleteLater();
        m_watcher = nullptr;
        m_importing = false;
        emit importingChanged();
        emit importFinished(report);
    });

    const QPointer<MinecraftAssetImporter> importer(this);
    const QFuture<QVariantMap> future = QtConcurrent::run([jarPath, itemsRootPath, importer] {
        return importGameJarImpl(jarPath, itemsRootPath, [importer](int value, const QString &status) {
            if (importer)
                emit importer->progressChanged(value, status);
        });
    });
    m_watcher->setFuture(future);
}
