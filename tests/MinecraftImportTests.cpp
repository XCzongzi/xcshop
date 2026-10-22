#include "MinecraftImportSupport.h"
#include <QtTest>
#include <QGuiApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QJsonDocument>
#include <QTemporaryDir>

using namespace MinecraftImport;

static bool bytes(const QString &path, const QByteArray &value) {
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) return false;
    QFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(value) == value.size();
}
static bool json(const QString &path, const QJsonObject &value) {
    return bytes(path, QJsonDocument(value).toJson(QJsonDocument::Compact));
}
static QJsonObject object(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}
static bool texture(const QString &root, const QString &name, const QColor &color) {
    QImage image(16, 16, QImage::Format_ARGB32);
    image.fill(color);
    return QDir().mkpath(root + "/textures/item") && image.save(root + "/textures/item/" + name + ".png");
}
static bool model(const QString &root, const QString &name, const QString &texture) {
    return json(root + "/models/item/" + name + ".json",
                {{"parent", "builtin/generated"}, {"textures", QJsonObject{{"layer0", "minecraft:item/" + texture}}}});
}

class MinecraftImportTests : public QObject {
    Q_OBJECT
private slots:
    void legacyAndModernRegistry() {
        QString error;
        const auto legacy = parseItemReports({}, {{"minecraft:stone", 1}, {"minecraft:air", 0}}, &error);
        QCOMPARE(legacy.size(), 2);
        QCOMPARE(legacy[0].toObject()["name"].toString(), "minecraft:air");
        const QJsonObject registry{{"minecraft:item", QJsonObject{{"entries", QJsonObject{
            {"minecraft:air", QJsonObject{{"protocol_id", 0}}}, {"minecraft:stone", QJsonObject{{"protocol_id", 1}}}}}}}};
        const auto modern = parseItemReports(registry, {{"minecraft:stone", QJsonObject{
            {"components", QJsonObject{{"minecraft:item_model", "minecraft:stone"}, {"minecraft:max_stack_size", 64}}}}}}, &error);
        QCOMPARE(modern.size(), 2);
        QCOMPARE(modern[1].toObject()["components"].toObject()["minecraft:max_stack_size"].toInt(), 64);
        QVERIFY(error.isEmpty());
        QVERIFY(parseItemReports({}, {{"minecraft:../escape", 0}}, &error).isEmpty());
        QVERIFY(!error.isEmpty());
        QVERIFY(parseItemReports({}, {}, &error).isEmpty());
    }
    void safeIdentifiers() {
        for (const auto &id : {"minecraft:stone", "example:folder/item"}) QVERIFY(validItemId(id));
        for (const auto &id : {"minecraft:../item", "minecraft:/item", "minecraft:a//b", "minecraft:a/./b", "minecraft:a/", "minecraft:Stone", "../item", "..:item", ".:item"})
            QVERIFY2(!validItemId(id), id);
    }
    void officialVersionOrdering() {
        const auto versions = parseVersions({{"versions", QJsonArray{
            QJsonObject{{"id", "1.13"}, {"type", "release"}, {"releaseTime", "2018-07-18T08:00:00Z"}},
            QJsonObject{{"id", "1.12.2"}, {"type", "release"}, {"releaseTime", "2017-09-18T08:00:00Z"}},
            QJsonObject{{"id", "26.10"}, {"type", "release"}, {"releaseTime", "2027-01-01T08:00:00Z"}},
            QJsonObject{{"id", "26.3-snapshot-1"}, {"type", "snapshot"}, {"releaseTime", "2026-07-01T08:00:00Z"}},
            QJsonObject{{"id", "../bad"}, {"type", "release"}, {"releaseTime", "2028-01-01T08:00:00Z"}}}}});
        QCOMPARE(versions.size(), 3);
        QCOMPARE(versions[0].toMap()["id"].toString(), "26.10");
        QCOMPARE(versions[2].toMap()["id"].toString(), "1.13");
    }
    void atomicActivation() {
        QTemporaryDir directory;
        const QString pack = "packs/" + QString(40, 'a') + "-r2-1234";
        QVERIFY(json(directory.path() + "/" + pack + "/catalog.json", {{"schemaVersion", CatalogSchema},
                     {"items", QJsonArray{QJsonObject{{"name", "minecraft:stone"}}}}}));
        QString error;
        QVERIFY(activatePack(directory.path(), pack, &error));
        QCOMPARE(activePack(directory.path()), pack);
        QVERIFY(!activatePack(directory.path(), "../outside", &error));
        QCOMPARE(activePack(directory.path()), pack);
        QVERIFY(!activatePack(directory.path(), "packs/" + QString(40, 'b') + "-r2-9999", &error));
        QCOMPARE(activePack(directory.path()), pack);
        QVERIFY(bytes(directory.path() + "/assets/custom/keep.png", "custom"));
        auto cancelled = std::make_shared<std::atomic_bool>(true);
        const auto report = importGame({{"itemsRoot", directory.path()}, {"version", "1.13"}}, cancelled, [](int, const QString &) {});
        QVERIFY(!report["ok"].toBool());
        QVERIFY(report["cancelled"].toBool());
        QCOMPARE(activePack(directory.path()), pack);
        QVERIFY(QFileInfo::exists(directory.path() + "/assets/custom/keep.png"));
    }
    void cachedImportNeedsNoJavaOrNetwork() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const QByteArray clientBytes("verified fixture client");
        const QString clientHash = QString::fromLatin1(QCryptographicHash::hash(clientBytes, QCryptographicHash::Sha1).toHex());
        const QString client = root + "/client.jar";
        QVERIFY(bytes(client, clientBytes));
        const QJsonObject metadata{{"id", "1.13"}, {"downloads", QJsonObject{
            {"client", QJsonObject{{"sha1", clientHash}}}}}};
        const QByteArray metaBytes = QJsonDocument(metadata).toJson(QJsonDocument::Compact);
        const auto metaHash = QString::fromLatin1(QCryptographicHash::hash(metaBytes, QCryptographicHash::Sha1).toHex());
        QVERIFY(bytes(root + "/cache/versions/1.13.json", metaBytes));
        QVERIFY(json(root + "/cache/manifest.json", {{"versions", QJsonArray{QJsonObject{
            {"id", "1.13"}, {"type", "release"}, {"releaseTime", "2018-07-18T08:00:00Z"}, {"sha1", metaHash}}}}}));
        const auto pack = "packs/" + clientHash + "-r2-1234";
        QVERIFY(json(root + "/" + pack + "/catalog.json", {{"schemaVersion", CatalogSchema},
            {"rendererVersion", RendererVersion}, {"clientSha1", clientHash}, {"gameVersion", "1.13"},
            {"items", QJsonArray{QJsonObject{{"name", "minecraft:stone"}}}}}));
        QVERIFY(json(root + "/cache/packs/" + clientHash + "-r" + QString::number(RendererVersion) + ".json", {{"pack", pack}}));
        const auto result = importGame({{"itemsRoot", root}, {"version", "1.13"},
            {"clientJar", client}, {"javaPath", "/nonexistent/java"}}, std::make_shared<std::atomic_bool>(false), [](int, const QString &) {});
        QVERIFY2(result["ok"].toBool(), qPrintable(result["message"].toString()));
        QCOMPARE(activePack(root), pack);
        const auto withoutClient = importGame({{"itemsRoot", root}, {"version", "1.13"}, {"javaPath", "/nonexistent/java"}},
            std::make_shared<std::atomic_bool>(false), [](int, const QString &) {});
        QVERIFY2(withoutClient["ok"].toBool(), qPrintable(withoutClient["message"].toString()));
        // A mismatched local client cannot replace the already active pack.
        QVERIFY(bytes(client, "wrong client"));
        const auto failed = importGame({{"itemsRoot", root}, {"version", "1.13"}, {"clientJar", client}},
            std::make_shared<std::atomic_bool>(false), [](int, const QString &) {});
        QVERIFY(!failed["ok"].toBool());
        QCOMPARE(activePack(root), pack);
    }
    void layeredGeneratedTexture() {
        QTemporaryDir directory;
        const auto root = directory.path();
        QVERIFY(texture(root, "base", Qt::red));
        QImage overlay(16, 16, QImage::Format_ARGB32);
        overlay.fill(Qt::transparent);
        overlay.setPixelColor(0, 0, Qt::blue);
        QVERIFY(overlay.save(root + "/textures/item/overlay.png"));
        QVERIFY(json(root + "/models/item/test.json", {{"parent", "builtin/generated"},
            {"textures", QJsonObject{{"layer0", "minecraft:item/base"}, {"layer1", "minecraft:item/overlay"}}}}));
        const auto output = root + "/icon.png";
        QCOMPARE(renderItem(root, "minecraft:test", {}, output).status, "rendered");
        const QImage rendered(output);
        QCOMPARE(rendered.pixelColor(0, 0), QColor(Qt::blue));
        QCOMPARE(rendered.pixelColor(63, 63), QColor(Qt::red));
    }
    void animationAndGuiSelection() {
        QTemporaryDir directory;
        const auto root = directory.path();
        QImage strip(16, 32, QImage::Format_ARGB32);
        strip.fill(Qt::red);
        for (int y = 16; y < 32; ++y) for (int x = 0; x < 16; ++x) strip.setPixelColor(x, y, Qt::green);
        QVERIFY(QDir().mkpath(root + "/textures/item"));
        QVERIFY(strip.save(root + "/textures/item/animated.png"));
        QVERIFY(json(root + "/textures/item/animated.png.mcmeta", {{"animation", QJsonObject{{"frames", QJsonArray{1, 0}}}}}));
        QVERIFY(model(root, "animated", "animated"));
        QVERIFY(texture(root, "other", Qt::blue));
        QVERIFY(model(root, "other", "other"));
        QVERIFY(bytes(root + "/items/test.json", R"({"model": {
            "type": "minecraft:select", "property": "minecraft:display_context",
            "cases": [{"when": "gui", "model": {"type": "minecraft:model", "model": "minecraft:item/animated"}}],
            "fallback": {"type": "minecraft:model", "model": "minecraft:item/other"}
        }})"));
        const auto output = root + "/icon.png";
        QCOMPARE(renderItem(root, "minecraft:test", {}, output).status, "rendered");
        QCOMPARE(QImage(output).pixelColor(32, 32), QColor(Qt::green));
    }
    void unknownModelsStayVisibleInCatalog() {
        QTemporaryDir directory;
        QVERIFY(json(directory.path() + "/items/test.json", {{"model", QJsonObject{{"type", "minecraft:future_type"}}}}));
        const auto result = renderItem(directory.path(), "minecraft:test", {}, directory.path() + "/icon.png");
        QCOMPARE(result.status, "missing");
        QVERIFY(result.reason.contains("future_type"));
        QCOMPARE(renderItem(directory.path(), "minecraft:air", {}, directory.path() + "/air.png").status, "empty");
    }
    void atlasPalette() {
        QTemporaryDir directory;
        const auto root = directory.path();
        QVERIFY(texture(root, "base", Qt::red));
        QVERIFY(texture(root, "key", Qt::red));
        QVERIFY(texture(root, "palette", Qt::yellow));
        QVERIFY(json(root + "/atlases/blocks.json", {{"sources", QJsonArray{QJsonObject{
            {"type", "minecraft:paletted_permutations"}, {"textures", QJsonArray{"minecraft:item/base"}},
            {"palette_key", "minecraft:item/key"}, {"permutations", QJsonObject{{"gold", "minecraft:item/palette"}}}}}}}));
        QVERIFY(model(root, "test", "base_gold"));
        const auto output = root + "/icon.png";
        QCOMPARE(renderItem(root, "minecraft:test", {}, output).status, "rendered");
        QCOMPARE(QImage(output).pixelColor(32, 32), QColor(Qt::yellow));
    }
};

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    const auto arguments = app.arguments();
    // Opt-in integration mode uses real official files, outside the default suite.
    if (arguments.size() >= 4 && arguments[1] == "--import") {
        const auto result = importGame({{"version", arguments[2]}, {"itemsRoot", arguments[3]},
            {"javaPath", arguments.value(4)}, {"rebuild", arguments.contains("--rebuild")}}, std::make_shared<std::atomic_bool>(false),
            [](int progress, const QString &message) { qInfo().noquote() << progress << message; });
        qInfo().noquote() << QJsonDocument::fromVariant(result).toJson(QJsonDocument::Compact);
        return result.value("ok").toBool() ? 0 : 1;
    }
    MinecraftImportTests tests;
    return QTest::qExec(&tests, argc, argv);
}
#include "MinecraftImportTests.moc"
