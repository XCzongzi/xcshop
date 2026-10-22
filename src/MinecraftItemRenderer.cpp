#include "MinecraftImportSupport.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QMatrix4x4>
#include <QPainter>
#include <QTransform>
#include <QtMath>
#include <QUrl>
#include <QVector3D>
#include <QHash>
#include <algorithm>
#include <array>
#include <limits>

namespace {

QJsonObject jsonObject(const QString &filePath)
{
    thread_local QHash<QString, QJsonObject> cache;
    if (cache.contains(filePath)) return cache.value(filePath);
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    const auto object = document.isObject() ? document.object() : QJsonObject{};
    if (cache.size() > 8192) cache.clear();
    cache.insert(filePath, object);
    return object;
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
    if (parent == "builtin/generated" || parent == "builtin/entity")
        result.insert("xcshopBuiltin", parent);
    if (!parent.isEmpty())
        if (!parent.startsWith("builtin/")) result = resolvedModel(assetsRoot, parent, depth + 1);

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
    if (!reference.startsWith('#') && textures.contains(reference)) reference.prepend('#');
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

QImage spriteImage(const QString &assetsRoot, QString sprite, int depth = 0)
{
    if (depth > 6) return {};
    if (sprite.startsWith("minecraft:")) sprite.remove(0, 10);
    if (sprite.contains(':') || sprite.startsWith('/') || sprite.split('/').contains("..")) return {};
    // Each worker keeps a bounded cache for exactly one extracted game root.
    thread_local QString cachedRoot;
    thread_local QHash<QString, QImage> cache;
    if (cachedRoot != assetsRoot) { cachedRoot = assetsRoot; cache.clear(); }
    if (cache.contains(sprite)) return cache.value(sprite);
    const QString path = assetsRoot + "/textures/" + sprite + ".png";
    QImage image(path);
    if (image.isNull()) {
        const QDir atlases(assetsRoot + "/atlases");
        for (const auto &atlas : atlases.entryList({"*.json"}, QDir::Files)) {
            for (const auto &value : jsonObject(atlases.filePath(atlas)).value("sources").toArray()) {
                const auto source = value.toObject();
                QString type = source.value("type").toString();
                type.remove("minecraft:");
                const auto plain = [](QString id) { return id.startsWith("minecraft:") ? id.mid(10) : id; };
                if (type == "single" && plain(source.value("sprite").toString(source.value("resource").toString())) == sprite) {
                    image = spriteImage(assetsRoot, source.value("resource").toString(), depth + 1);
                } else if (type == "directory") {
                    const auto prefix = source.value("prefix").toString();
                    if (!prefix.isEmpty() && sprite.startsWith(prefix))
                        image = spriteImage(assetsRoot, source.value("source").toString() + "/" + sprite.mid(prefix.size()), depth + 1);
                } else if (type == "unstitch") {
                    for (const auto &regionValue : source.value("regions").toArray()) {
                        const auto region = regionValue.toObject();
                        if (plain(region.value("sprite").toString()) != sprite) continue;
                        const auto base = spriteImage(assetsRoot, source.value("resource").toString(), depth + 1);
                        const double dx = source.value("divisor_x").toDouble(1), dy = source.value("divisor_y").toDouble(1);
                        if (!base.isNull() && dx > 0 && dy > 0)
                            image = base.copy(qRound(region.value("x").toDouble() / dx * base.width()),
                                              qRound(region.value("y").toDouble() / dy * base.height()),
                                              qRound(region.value("width").toDouble() / dx * base.width()),
                                              qRound(region.value("height").toDouble() / dy * base.height()));
                    }
                } else if (type == "paletted_permutations") {
                    const auto permutations = source.value("permutations").toObject();
                    for (auto permutation = permutations.begin(); permutation != permutations.end(); ++permutation) {
                        for (const auto &texture : source.value("textures").toArray()) {
                            const QString baseId = plain(texture.toString());
                            if (baseId + "_" + permutation.key() != sprite) continue;
                            image = spriteImage(assetsRoot, baseId, depth + 1).convertToFormat(QImage::Format_ARGB32);
                            const auto keys = spriteImage(assetsRoot, source.value("palette_key").toString(), depth + 1);
                            const auto colors = spriteImage(assetsRoot, permutation.value().toString(), depth + 1);
                            if (keys.size() != colors.size() || keys.isNull()) { image = {}; continue; }
                            QHash<QRgb, QRgb> replacements;
                            for (int y = 0; y < keys.height(); ++y)
                                for (int x = 0; x < keys.width(); ++x)
                                    replacements.insert(keys.pixel(x, y) & 0xffffff, colors.pixel(x, y));
                            for (int y = 0; y < image.height(); ++y) for (int x = 0; x < image.width(); ++x) {
                                const auto before = image.pixel(x, y);
                                if (!replacements.contains(before & 0xffffff)) continue;
                                const auto after = replacements.value(before & 0xffffff);
                                image.setPixel(x, y, qRgba(qRed(after), qGreen(after), qBlue(after), qAlpha(before) * qAlpha(after) / 255));
                            }
                        }
                    }
                }
                if (!image.isNull()) break;
            }
            if (!image.isNull()) break;
        }
    }
    const auto metadata = jsonObject(path + ".mcmeta");
    const auto animation = metadata.value("animation").toObject();
    if (!image.isNull() && metadata.value("animation").isObject()) {
        const int side = qMin(image.width(), image.height());
        const int width = animation.value("width").toInt(side);
        const int height = animation.value("height").toInt(side);
        const auto frames = animation.value("frames").toArray();
        const auto first = frames.isEmpty() ? QJsonValue(0) : frames.first();
        const int frame = first.isObject() ? first.toObject().value("index").toInt() : first.toInt();
        if (width > 0 && height > 0 && width <= image.width() && height <= image.height()) {
            const int columns = image.width() / width;
            if (frame >= 0 && frame < columns * (image.height() / height))
                image = image.copy((frame % columns) * width, (frame / columns) * height, width, height);
        }
    }
    cache.insert(sprite, image);
    return image;
}

QImage faceImage(const QString &assetsRoot, const QJsonObject &textures, const QJsonObject &face,
                 const QString &direction, const QVector3D &from, const QVector3D &to)
{
    QImage image = spriteImage(assetsRoot, resolveTexture(textures, face.value("texture").toString()));
    if (image.isNull())
        return {};
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
    if (rotation.contains("axis")) matrix.rotate(float(rotation.value("angle").toDouble()), axisVector);
    else {
        matrix.rotate(float(rotation.value("z").toDouble()), 0, 0, 1);
        matrix.rotate(float(rotation.value("y").toDouble()), 0, 1, 0);
        matrix.rotate(float(rotation.value("x").toDouble()), 1, 0, 0);
    }
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

bool renderModelIcon(const QString &assetsRoot, const QJsonObject &model, const QString &outputPath,
                     const QColor &tint = {})
{
    const QJsonArray elements = model.value("elements").toArray();
    const QJsonObject textures = model.value("textures").toObject();
    if (elements.isEmpty())
        return false;

    struct Face {
        QImage image;
        std::array<QPointF, 4> points;
        std::array<float, 4> depths;
        qreal shade = 1.0;
        bool translucent = false;
    };
    QVector<Face> faces;
    const QVector3D camera(0, 0, 1);
    const QVector3D light = model.value("gui_light").toString() == "front"
        ? QVector3D(0, 0, 1) : QVector3D(-0.35f, 0.7f, 1).normalized();
    const QMatrix4x4 gui = guiTransform(model);
    const auto colors = model.value("xcshopTints").toArray();
    auto addFace = [&faces, &assetsRoot, &textures, &camera, &light, &tint, &colors](const QString &direction, const QJsonObject &face,
                                                                               const QVector<QVector3D> &vertices,
                                                                               const QVector3D &elementFrom, const QVector3D &elementTo,
                                                                               const QMatrix4x4 &transform) {
        QImage image = faceImage(assetsRoot, textures, face, direction, elementFrom, elementTo);
        if (image.isNull())
            return;
        QColor color = tint;
        const int index = face.value("tintindex").toInt(-1);
        if (index >= 0 && index < colors.size()) color = QColor::fromRgb(colors[index].toInt() & 0xffffff);
        image = tinted(image, color);
        bool translucent = false;
        for (int y = 0; y < image.height() && !translucent; ++y)
            for (int x = 0; x < image.width(); ++x) {
                const int alpha = qAlpha(image.pixel(x, y));
                if (alpha > 0 && alpha < 255) { translucent = true; break; }
            }
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
                       QVector3D::dotProduct(p2_3d, camera), QVector3D::dotProduct(p3_3d, camera)}, shade, translucent});
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

    std::stable_sort(faces.begin(), faces.end(), [](const Face &a, const Face &b) {
        if (a.translucent != b.translucent) return !a.translucent;
        const auto depth = [](const Face &face) { return face.depths[0] + face.depths[1] + face.depths[2] + face.depths[3]; };
        return depth(a) < depth(b);
    });

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
                const QRgb before = pixels[x];
                const qreal alpha = qAlpha(source) / 255.0;
                const qreal previousAlpha = qAlpha(before) / 255.0;
                const qreal combinedAlpha = alpha + previousAlpha * (1 - alpha);
                const auto blend = [alpha, previousAlpha, combinedAlpha, &face](int sourceChannel, int previousChannel) {
                    return qRound((sourceChannel * face.shade * alpha + previousChannel * previousAlpha * (1 - alpha)) / combinedAlpha);
                };
                pixels[x] = qRgba(blend(qRed(source), qRed(before)), blend(qGreen(source), qGreen(before)),
                                 blend(qBlue(source), qBlue(before)), qRound(combinedAlpha * 255));
            }
        }
    };
    for (const Face &face : faces) {
        rasterizeTriangle(face, 0, 1, 2);
        rasterizeTriangle(face, 0, 2, 3);
    }
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
    QString texture = "entity/banner/banner_base";
    if (!QFileInfo::exists(assetsRoot + "/textures/" + texture + ".png")) texture = "entity/banner_base";
    if (!dye.isValid() || !QFileInfo::exists(assetsRoot + "/textures/" + texture + ".png")) return false;

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
    model.insert("textures", QJsonObject{{"banner", texture}});
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
    QString texture = headTextureReference(name);
    if (name == "player_head" && !QFileInfo::exists(assetsRoot + "/textures/" + texture + ".png"))
        texture = "entity/steve";
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

bool renderBuiltinEntity(const QString &assetsRoot, const QString &name, const QString &outputPath)
{
    QJsonObject model{{"gui_light", "side"}};
    QJsonArray elements;
    QString texture;
    const auto box = [&elements](const QJsonArray &from, const QJsonArray &to,
                                int tw, int th, int u, int v, int w, int h, int d) {
        elements.append(QJsonObject{{"from", from}, {"to", to},
            {"faces", entityBoxFaces("#entity", tw, th, u, v, w, h, d)}});
    };
    if (name.endsWith("_bed")) {
        texture = "entity/bed/" + name.left(name.size() - 4);
        box({0, 3, 0}, {16, 9, 16}, 64, 64, 0, 0, 16, 6, 16);
        box({0, 3, 16}, {16, 9, 32}, 64, 64, 0, 22, 16, 6, 16);
        for (int x : {0, 13}) for (int z : {0, 29})
            box({x, 0, z}, {x + 3, 3, z + 3}, 64, 64, 50, 0, 3, 3, 3);
        model.insert("display", QJsonObject{{"gui", QJsonObject{{"rotation", QJsonArray{30, 225, 0}},
            {"translation", QJsonArray{0, -1, 0}}, {"scale", QJsonArray{0.38, 0.38, 0.38}}}}});
    } else if (name == "shield") {
        texture = "entity/shield_base_nopattern";
        if (!QFileInfo::exists(assetsRoot + "/textures/" + texture + ".png")) texture = "entity/shield/shield_base_nopattern";
        box({2, -3, 7}, {14, 19, 8}, 64, 64, 0, 0, 12, 22, 1);
        box({7, 5, 8}, {9, 11, 14}, 64, 64, 26, 0, 2, 6, 6);
        model.insert("display", QJsonObject{{"gui", QJsonObject{{"rotation", QJsonArray{15, 205, 0}},
            {"scale", QJsonArray{0.58, 0.58, 0.58}}}}});
    } else if (name == "conduit") {
        texture = "entity/conduit/base";
        box({5, 5, 5}, {11, 11, 11}, 32, 16, 0, 0, 6, 6, 6);
        model.insert("display", QJsonObject{{"gui", QJsonObject{{"scale", QJsonArray{1.2, 1.2, 1.2}}}}});
    } else if (name == "dragon_head") {
        texture = "entity/enderdragon/dragon";
        box({0, 0, 0}, {16, 16, 16}, 256, 256, 112, 30, 16, 16, 16);
        box({2, 7, -16}, {14, 12, 0}, 256, 256, 176, 44, 12, 5, 16);
        box({2, -2, 0}, {4, 0, 4}, 256, 256, 0, 0, 2, 4, 2);
        box({12, -2, 0}, {14, 0, 4}, 256, 256, 0, 0, 2, 4, 2);
        model.insert("display", QJsonObject{{"gui", QJsonObject{{"rotation", QJsonArray{20, 210, 0}},
            {"scale", QJsonArray{0.42, 0.42, 0.42}}}}});
    } else if (name == "decorated_pot") {
        texture = "entity/decorated_pot/decorated_pot_side";
        QJsonObject faces;
        for (const auto &direction : {"up", "down", "north", "south", "east", "west"})
            faces.insert(direction, QJsonObject{{"texture", "#entity"}, {"uv", QJsonArray{0, 0, 16, 16}}});
        elements.append(QJsonObject{{"from", QJsonArray{1, 0, 1}}, {"to", QJsonArray{15, 13, 15}}, {"faces", faces}});
        elements.append(QJsonObject{{"from", QJsonArray{4, 13, 4}}, {"to", QJsonArray{12, 16, 12}}, {"faces", faces}});
    } else if (name.endsWith("copper_golem_statue")) {
        texture = "entity/copper_golem/copper_golem";
        if (name.contains("exposed_")) texture += "_exposed";
        else if (name.contains("weathered_")) texture += "_weathered";
        else if (name.contains("oxidized_")) texture += "_oxidized";
        box({4, 10, 4}, {12, 18, 12}, 64, 64, 0, 0, 8, 8, 8);
        box({5, 4, 5}, {11, 11, 11}, 64, 64, 0, 16, 6, 7, 6);
        box({5, 0, 6}, {7, 5, 10}, 64, 64, 26, 16, 2, 5, 4);
        box({9, 0, 6}, {11, 5, 10}, 64, 64, 26, 16, 2, 5, 4);
        box({3, 4, 6}, {5, 10, 10}, 64, 64, 26, 0, 2, 6, 4);
        box({11, 4, 6}, {13, 10, 10}, 64, 64, 26, 0, 2, 6, 4);
        box({7, 18, 7}, {9, 22, 9}, 64, 64, 48, 0, 2, 4, 2);
        model.insert("display", QJsonObject{{"gui", QJsonObject{{"scale", QJsonArray{0.50, 0.50, 0.50}}}}});
    } else return false;
    if (!QFileInfo::exists(assetsRoot + "/textures/" + texture + ".png")) return false;
    model.insert("textures", QJsonObject{{"entity", texture}});
    model.insert("elements", elements);
    return renderModelIcon(assetsRoot, model, outputPath);
}

} // namespace

namespace MinecraftImport {
namespace {
QString bare(QString value) { return value.startsWith("minecraft:") ? value.mid(10) : value; }

class DefaultIconRenderer {
public:
    QString root, name, output;
    QJsonObject components;
    QStringList approximations;
    QStringList failures;
    int part = 0;
    bool builtinPreview = false;
    bool intentionallyEmpty = false;

    QColor tintColor(const QJsonObject &definition) {
        const auto type = bare(definition.value("type").toString());
        const auto rgb = [](const QJsonValue &value, int fallback) {
            if (value.isDouble()) return QColor::fromRgb(value.toInt() & 0xffffff);
            if (value.isArray()) {
                const auto a = value.toArray();
                if (a.size() == 3) return QColor::fromRgbF(qBound(0.0, a[0].toDouble(), 1.0),
                       qBound(0.0, a[1].toDouble(), 1.0), qBound(0.0, a[2].toDouble(), 1.0));
            }
            return QColor::fromRgb(fallback);
        };
        if (type == "constant") return rgb(definition.value("value"), 0xffffff);
        if (type == "dye") return rgb(components.value("minecraft:dyed_color"), definition.value("default").toInt(0xa06540));
        if (type == "potion") {
            const auto potion = components.value("minecraft:potion_contents").toObject();
            if (potion.contains("custom_color")) return rgb(potion.value("custom_color"), 0x385dc6);
            return rgb(definition.value("default"), 0x385dc6);
        }
        if (type == "grass") {
            const auto image = spriteImage(root, "colormap/grass");
            const double temperature = qBound(0.0, definition.value("temperature").toDouble(0.5), 1.0);
            const double rain = qBound(0.0, definition.value("downfall").toDouble(1.0), 1.0) * temperature;
            if (!image.isNull()) return image.pixelColor(qRound((1 - temperature) * (image.width() - 1)),
                                                         qRound((1 - rain) * (image.height() - 1)));
        }
        if (type == "map_color" || type == "firework" || type == "custom_model_data" || type == "team")
            return rgb(definition.value("default"), 0xffffff);
        approximations << "未实现的着色类型：" + type;
        return rgb(definition.value("default"), 0xffffff);
    }

    QJsonArray legacyColors(const QJsonObject &model) {
        const auto textures = model.value("textures").toObject();
        if (name.endsWith("_spawn_egg")) {
            approximations << "旧版刷怪蛋颜色由游戏代码定义，使用中性色预览。";
            return {0xaaaaaa, 0x666666};
        }
        if (name.startsWith("leather_")) return {0xa06540};
        if (name == "potion" || name == "splash_potion" || name == "lingering_potion" || name == "tipped_arrow")
            return {0x385dc6};
        if (name == "birch_leaves") return {0x80a755};
        if (name == "spruce_leaves") return {0x619961};
        if (name.endsWith("_leaves") || name == "vine" || name == "lily_pad") {
            approximations << "使用默认植被颜色预览。";
            return {0x48b518};
        }
        for (const auto &value : textures) {
            if (value.toString().contains("grass") || value.toString().contains("fern"))
                return {int(tintColor({{"type", "minecraft:grass"}}).rgb() & 0xffffff)};
        }
        return {};
    }

    QImage modelImage(QJsonObject model) {
        if (model.isEmpty()) return {};
        // The default legacy item stack has no use animation, damage or custom
        // model data. Only overrides whose predicates hold for that state apply.
        for (const auto &value : model.value("overrides").toArray()) {
            const auto choice = value.toObject();
            bool matches = true;
            const auto predicates = choice.value("predicate").toObject();
            for (auto it = predicates.begin(); it != predicates.end(); ++it)
                if (it.value().toDouble() > 0) matches = false;
            if (matches && !predicates.isEmpty()) {
                const auto replacement = resolvedModel(root, choice.value("model").toString());
                if (!replacement.isEmpty()) model = replacement;
            }
        }
        if (!model.contains("xcshopTints")) model.insert("xcshopTints", legacyColors(model));
        const auto textures = model.value("textures").toObject();
        const auto colors = model.value("xcshopTints").toArray();
        if (model.value("xcshopBuiltin").toString() == "builtin/generated"
            || (model.value("elements").toArray().isEmpty() && textures.contains("layer0"))) {
            QImage combined(64, 64, QImage::Format_ARGB32_Premultiplied);
            combined.fill(Qt::transparent);
            QPainter painter(&combined);
            bool any = false;
            for (int layer = 0; layer < 16; ++layer) {
                const auto entry = textures.value("layer" + QString::number(layer));
                if (entry.isUndefined()) continue;
                const auto reference = entry.isObject() ? entry.toObject().value("sprite").toString() : entry.toString();
                auto image = spriteImage(root, resolveTexture(textures, reference));
                if (image.isNull()) { failures << "贴图缺失：" + reference; continue; }
                if (layer < colors.size()) image = tinted(image, QColor::fromRgb(colors[layer].toInt() & 0xffffff));
                painter.drawImage(QRect(0, 0, 64, 64), image);
                any = true;
            }
            painter.end();
            return any ? combined : QImage{};
        }
        const QString temporary = output + ".part-" + QString::number(++part) + ".png";
        if (renderModelIcon(root, model, temporary)) {
            QImage image(temporary);
            QFile::remove(temporary);
            return image;
        }
        return {};
    }

    QImage specialImage() {
        const QString temporary = output + ".special.png";
        if (renderSpecialItemIcon(root, name, temporary) || renderBuiltinEntity(root, name, temporary)) {
            QImage image(temporary);
            QFile::remove(temporary);
            approximations << "使用特殊物品的本地几何预览。";
            builtinPreview = true;
            return image;
        }
        return {};
    }

    QImage node(const QJsonObject &definition, int depth = 0) {
        if (depth > 32) { failures << "模型定义嵌套过深。"; return {}; }
        const auto type = bare(definition.value("type").toString());
        QImage image;
        if (type == "empty" || type == "bundle/selected_item") {
            intentionallyEmpty = true;
            image = QImage(64, 64, QImage::Format_ARGB32_Premultiplied);
            image.fill(Qt::transparent);
        } else if (type == "model") {
            auto model = resolvedModel(root, definition.value("model").toString());
            QJsonArray tints;
            for (const auto &value : definition.value("tints").toArray())
                tints.append(int(tintColor(value.toObject()).rgb() & 0xffffff));
            model.insert("xcshopTints", tints);
            image = modelImage(model);
        } else if (type == "special") {
            image = specialImage();
            if (image.isNull()) {
                approximations << "特殊渲染器尚未实现：" + definition.value("model").toObject().value("type").toString();
                image = modelImage(resolvedModel(root, definition.value("base").toString()));
            }
        } else if (type == "composite") {
            image = QImage(64, 64, QImage::Format_ARGB32_Premultiplied);
            image.fill(Qt::transparent);
            QPainter painter(&image);
            bool any = false;
            for (const auto &value : definition.value("models").toArray()) {
                const auto sub = node(value.toObject(), depth + 1);
                if (sub.isNull()) continue;
                painter.drawImage(0, 0, sub);
                any = true;
            }
            painter.end();
            if (!any) image = {};
            approximations << "组合模型按子模型顺序合成预览。";
        } else if (type == "condition") {
            const auto property = bare(definition.value("property").toString());
            bool enabled = false;
            if (property == "has_component" || property == "component")
                enabled = components.contains(definition.value("component").toString());
            else if (!QStringList{"using_item", "broken", "carried", "selected", "extended_view", "fishing_rod/cast", "bundle/has_selected_item", "view_entity", "keybind_down"}.contains(property))
                approximations << "条件使用默认状态：" + property;
            image = node(definition.value(enabled ? "on_true" : "on_false").toObject(), depth + 1);
        } else if (type == "select") {
            const auto property = bare(definition.value("property").toString());
            QString actual;
            if (property == "display_context") actual = "gui";
            else if (property == "main_hand") actual = "right";
            else if (property == "context_entity_type") actual = "minecraft:player";
            else if (property == "context_dimension") actual = "minecraft:overworld";
            else if (property == "charge_type") actual = "none";
            else if (property == "component") actual = components.value(definition.value("component").toString()).toString();
            else approximations << "选择器使用默认状态：" + property;
            auto selected = definition.value("fallback").toObject();
            for (const auto &value : definition.value("cases").toArray()) {
                const auto choice = value.toObject();
                const auto when = choice.value("when");
                bool matches = when.toString() == actual && when.isString();
                for (const auto &entry : when.toArray()) if (entry.toString() == actual) matches = true;
                if (matches) { selected = choice.value("model").toObject(); break; }
            }
            image = node(selected, depth + 1);
        } else if (type == "range_dispatch") {
            const auto property = bare(definition.value("property").toString());
            double actual = property == "count" ? 1.0 : 0.0;
            if (property == "count" && definition.value("normalize").toBool(true))
                actual /= qMax(1, components.value("minecraft:max_stack_size").toInt(64));
            if (!QStringList{"count", "damage", "use_duration", "crossbow/pull", "cooldown", "use_cycle", "custom_model_data", "bundle/fullness"}.contains(property))
                approximations << "环境相关模型使用固定默认状态：" + property;
            actual *= definition.value("scale").toDouble(1);
            auto selected = definition.value("fallback").toObject();
            double threshold = -std::numeric_limits<double>::infinity();
            for (const auto &value : definition.value("entries").toArray()) {
                const auto entry = value.toObject();
                const double candidate = entry.value("threshold").toDouble();
                if (candidate <= actual && candidate >= threshold) { threshold = candidate; selected = entry.value("model").toObject(); }
            }
            image = node(selected, depth + 1);
        } else {
            failures << "未知模型类型：" + (type.isEmpty() ? QString("未指定") : type);
        }
        if (!image.isNull() && definition.contains("transformation") && !builtinPreview) {
            approximations << "子模型变换使用二维投影预览。";
            const auto transform = definition.value("transformation").toObject();
            const auto scale = transform.value("scale").toArray();
            const auto translation = transform.value("translation").toArray();
            QImage moved(image.size(), QImage::Format_ARGB32_Premultiplied);
            moved.fill(Qt::transparent);
            QPainter painter(&moved);
            painter.translate(32, 32);
            if (translation.size() == 3) painter.translate(translation[0].toDouble() * 64, -translation[1].toDouble() * 64);
            if (scale.size() == 3) painter.scale(scale[0].toDouble(1), scale[1].toDouble(1));
            painter.drawImage(-32, -32, image);
            painter.end();
            image = moved;
        }
        return image;
    }
};
} // namespace

IconResult renderItem(const QString &assetsRoot, const QString &id,
                      const QJsonObject &components, const QString &outputPath)
{
    if (!validItemId(id) || !id.startsWith("minecraft:")) return {"missing", "无效的原版物品 ID。"};
    if (id == "minecraft:air") return {"empty", "空气没有物品图标。"};
    DefaultIconRenderer renderer;
    renderer.root = assetsRoot;
    renderer.name = id.mid(10);
    renderer.output = outputPath;
    renderer.components = components;
    QString modelId = components.value("minecraft:item_model").toString(id);
    if (!modelId.contains(':')) modelId.prepend("minecraft:");
    QImage image;
    if (validItemId(modelId) && modelId.startsWith("minecraft:")) {
        const QString definitionFile = assetsRoot + "/items/" + modelId.mid(10) + ".json";
        if (QFileInfo::exists(definitionFile))
            image = renderer.node(jsonObject(definitionFile).value("model").toObject());
        else {
            image = renderer.specialImage();
            if (image.isNull()) image = renderer.modelImage(resolvedModel(assetsRoot, "item/" + modelId.mid(10)));
        }
    }
    if (image.isNull()) {
        const auto fallback = spriteImage(assetsRoot, "item/" + renderer.name);
        if (!fallback.isNull()) {
            image = fallback.scaled(64, 64, Qt::KeepAspectRatio, Qt::FastTransformation);
            renderer.approximations << "模型无法完整渲染，使用原始物品贴图。";
        }
    }
    renderer.approximations.removeDuplicates();
    renderer.failures.removeDuplicates();
    if (!image.isNull()) {
        bool visible = false;
        for (int y = 0; y < image.height() && !visible; ++y)
            for (int x = 0; x < image.width(); ++x) if (qAlpha(image.pixel(x, y))) { visible = true; break; }
        if (!visible && renderer.intentionallyEmpty && image.save(outputPath, "PNG"))
            return {"empty", "该物品默认状态不绘制图标。"};
        if (!visible) {
            // Known entity-style items can also be expressed as transformed
            // composite block models. Reuse their geometry preview if that
            // coordinate convention cannot be projected faithfully yet.
            const auto preview = renderer.specialImage();
            if (!preview.isNull()) image = preview;
            else { renderer.failures << "默认模型投影不可见。"; image = {}; }
        }
    }
    if (image.isNull() || !image.save(outputPath, "PNG")) {
        const auto reasons = renderer.failures + renderer.approximations;
        return {"missing", reasons.isEmpty() ? "缺少可渲染的默认物品模型。" : reasons.join(' ')};
    }
    if (!renderer.failures.isEmpty()) renderer.approximations << renderer.failures;
    return {renderer.approximations.isEmpty() ? "rendered" : "approximate", renderer.approximations.join(' ')};
}
} // namespace MinecraftImport
