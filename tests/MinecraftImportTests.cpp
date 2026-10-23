#include "MinecraftImportSupport.h"
#include <QtTest>
#include <QGuiApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QJsonDocument>
#include <QLockFile>
#include <QProcess>
#include <QStandardPaths>
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
static QString fixtureClient(const QString &root, const QString &id = "1.21.4") {
    const auto content = root + "/content";
    if (!json(content + "/version.json", {{"id", id}, {"world_version", 4189}})
        || !texture(content + "/assets/minecraft", "stone", Qt::gray)
        || !model(content + "/assets/minecraft", "stone", "stone")) return {};
    const QString jar = root + "/versions/" + id + "/renamed-client.jar";
    if (!QDir().mkpath(QFileInfo(jar).absolutePath())) return {};
    if (QProcess::execute(QStandardPaths::findExecutable("tar"),
                         {"--format=zip", "-cf", jar, "-C", content, "version.json", "assets"}) != 0) return {};
    return jar;
}
static QString fileHash(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    return QString::fromLatin1(QCryptographicHash::hash(file.readAll(), QCryptographicHash::Sha1).toHex());
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
    void versionPickerHonorsOfflineChoice() {
        QTemporaryDir directory;
        QVERIFY(json(directory.path() + "/cache/manifest.json", {{"versions", QJsonArray{QJsonObject{
            {"id", "1.13"}, {"type", "release"}, {"releaseTime", "2018-07-18T08:00:00Z"}}}}}));
        const auto result = fetchVersions(directory.path(), {}, false);
        QVERIFY2(result["ok"].toBool(), qPrintable(result["message"].toString()));
        QCOMPARE(result["versions"].toList().size(), 1);
        QTemporaryDir empty;
        QVERIFY(!fetchVersions(empty.path(), {}, false)["ok"].toBool());
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
    void switchingImportedVersionsUsesOnlyCompletedLocalPacks() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const auto first = "packs/" + QString(40, 'a') + "-r2-1111";
        const auto second = "packs/" + QString(40, 'b') + "-r2-2222";
        const auto duplicate = "packs/" + QString(40, 'c') + "-r2-3333";
        const auto broken = "packs/" + QString(40, 'd') + "-r2-4444";
        const auto save = [&](const QString &pack, const QString &version, const QString &date) {
            return json(root + "/" + pack + "/catalog.json", {{"schemaVersion", CatalogSchema},
                {"rendererVersion", RendererVersion}, {"gameVersion", version}, {"createdAt", date},
                {"items", QJsonArray{QJsonObject{{"name", "minecraft:stone"}}}}});
        };
        QVERIFY(save(first, "1.13", "2024-01-01T00:00:00Z"));
        QVERIFY(save(second, "1.21.4", "2025-01-01T00:00:00Z"));
        QVERIFY(save(duplicate, "1.21.4", "2024-01-01T00:00:00Z"));
        QVERIFY(json(root + "/" + broken + "/catalog.json", {{"schemaVersion", CatalogSchema}, {"gameVersion", "broken"}}));
        QVERIFY(bytes(root + "/assets/custom/keep.png", "custom"));
        QString error;
        QVERIFY(activatePack(root, first, &error));
        const auto versions = importedPacks(root);
        QCOMPARE(versions.size(), 2);
        QVERIFY(versions[0].toMap()["active"].toBool());
        QCOMPARE(versions[1].toMap()["pack"].toString(), second);
        const auto switched = switchPack(root, second);
        QVERIFY2(switched["ok"].toBool(), qPrintable(switched["message"].toString()));
        QCOMPARE(switched["gameVersion"].toString(), "1.21.4");
        QVERIFY(!switched.contains("items"));
        QCOMPARE(activePack(root), second);
        QVERIFY(QFileInfo::exists(root + "/assets/custom/keep.png"));
        QVERIFY(!QFileInfo::exists(root + "/cache/manifest.json"));
        QLockFile lock(root + "/cache/import.lock");
        QVERIFY(lock.tryLock());
        QVERIFY(!switchPack(root, first)["ok"].toBool());
        QCOMPARE(activePack(root), second);
        lock.unlock();
        QVERIFY(!switchPack(root, "../outside")["ok"].toBool());
        QVERIFY(QFile::remove(root + "/" + first + "/catalog.json"));
        QVERIFY(!switchPack(root, first)["ok"].toBool());
        QCOMPARE(activePack(root), second);
    }
    void cachedImportNeedsNoJavaOrNetwork() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const QByteArray clientBytes("verified fixture client");
        const QString clientHash = QString::fromLatin1(QCryptographicHash::hash(clientBytes, QCryptographicHash::Sha1).toHex());
        const QString client = root + "/1.13.jar";
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
            {"clientJar", client}, {"allowNetwork", false}, {"javaPath", "/nonexistent/java"}}, std::make_shared<std::atomic_bool>(false), [](int, const QString &) {});
        QVERIFY2(result["ok"].toBool(), qPrintable(result["message"].toString()));
        QCOMPARE(activePack(root), pack);
        const auto withoutClient = importGame({{"itemsRoot", root}, {"version", "1.13"}, {"allowNetwork", false}, {"javaPath", "/nonexistent/java"}},
            std::make_shared<std::atomic_bool>(false), [](int, const QString &) {});
        QVERIFY2(withoutClient["ok"].toBool(), qPrintable(withoutClient["message"].toString()));
        // A mismatched local client cannot replace the already active pack.
        QVERIFY(bytes(client, "wrong client"));
        const auto failed = importGame({{"itemsRoot", root}, {"version", "1.13"}, {"clientJar", client}, {"allowNetwork", false}},
            std::make_shared<std::atomic_bool>(false), [](int, const QString &) {});
        QVERIFY(!failed["ok"].toBool());
        QCOMPARE(activePack(root), pack);
    }
    void localVersionAndOfflineCachedReports() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const auto jar = fixtureClient(root + "/game");
        QVERIFY(!jar.isEmpty());
        const auto hash = fileHash(jar);
        const QJsonObject metadata{{"id", "1.21.4"}, {"mainClass", "net.minecraft.client.main.Main"},
            {"downloads", QJsonObject{{"client", QJsonObject{{"sha1", hash}}}}}};
        QVERIFY(json(QFileInfo(jar).absolutePath() + "/renamed-client.json", metadata));
        const auto probe = inspectLocalInstallation(jar, {});
        QVERIFY2(probe["ok"].toBool(), qPrintable(probe["message"].toString()));
        QCOMPARE(probe["version"].toString(), "1.21.4");
        const auto folder = inspectLocalInstallation(root + "/game", {});
        QCOMPARE(folder["clientJar"].toString(), jar);
        const auto reports = root + "/items/cache/reports/" + hash + "-client";
        QVERIFY(json(reports + "/items.json", {{"minecraft:air", 0}, {"minecraft:stone", 1}}));
        QVERIFY(json(reports + "/complete.json", {{"clientSha1", hash}, {"componentsVersion", 1}}));
        const QVariantMap options{{"itemsRoot", root + "/items"}, {"source", "local"}, {"sourcePath", jar},
            {"version", "wrong-online-selection"}, {"allowNetwork", false}, {"javaPath", "/nonexistent/java"}};
        const auto result = importGame(options, {}, [](int, const QString &) {});
        QVERIFY2(result["ok"].toBool(), qPrintable(result["message"].toString()));
        QCOMPARE(result["gameVersion"].toString(), "1.21.4");
        QCOMPARE(result["generator"].toString(), "client");
        QCOMPARE(result["itemCount"].toInt(), 2);
        QVERIFY(!QFileInfo::exists(root + "/items/cache/manifest.json"));
        QVERIFY(QFileInfo::exists(root + "/items/" + activePack(root + "/items") + "/assets/minecraft/stone.png"));
        QVERIFY(QFile::remove(QFileInfo(jar).absolutePath() + "/renamed-client.json"));
        // The completed pack can now be reactivated without even version metadata.
        const auto cached = importGame(options, {}, [](int, const QString &) {});
        QVERIFY2(cached["ok"].toBool(), qPrintable(cached["message"].toString()));
    }
    void legacyDetectionRejectsLoaderWithoutGame() {
        QTemporaryDir directory;
        const auto old = directory.path() + "/old/observer.jar";
        QVERIFY(bytes(old, "legacy client"));
        QVERIFY(json(directory.path() + "/old/observer.json", {{"id", "1.13"}, {"mainClass", "net.minecraft.client.main.Main"}}));
        QCOMPARE(inspectLocalInstallation(old, {})["version"].toString(), "1.13");
        QVERIFY(json(directory.path() + "/old/observer.json", {{"id", "1.21.4-fabric"}, {"inheritsFrom", "missing-base-for-test-06c7f"}}));
        QVERIFY(!inspectLocalInstallation(old, {})["ok"].toBool());
        QVERIFY(!inspectLocalInstallation(directory.path() + "/missing.jar", {})["ok"].toBool());
    }
    void localFolderChoosesLatestReleaseTime() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const auto newest = fixtureClient(root, "1.21.4");
        const auto older = fixtureClient(root, "1.13");
        QVERIFY(!newest.isEmpty() && !older.isEmpty());
        QVERIFY(json(QFileInfo(newest).absolutePath() + "/renamed-client.json", {{"id", "1.21.4"}, {"releaseTime", "2024-12-03T12:00:00Z"}}));
        QVERIFY(json(QFileInfo(older).absolutePath() + "/renamed-client.json", {{"id", "1.13"}, {"releaseTime", "2018-07-18T12:00:00Z"}}));
        const auto result = inspectLocalInstallation(root, {});
        QVERIFY2(result["ok"].toBool(), qPrintable(result["message"].toString()));
        QCOMPARE(result["version"].toString(), "1.21.4");
        QCOMPARE(result["count"].toInt(), 2);
    }
    void originalClientInsideModpackIsAccepted() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const auto jar = fixtureClient(root + "/game");
        QVERIFY(!jar.isEmpty());
        const QByteArray library("base library");
        const auto libraryHash = QString::fromLatin1(QCryptographicHash::hash(library, QCryptographicHash::Sha1).toHex());
        QVERIFY(bytes(root + "/game/libraries/example/core/1/core-1.jar", library));
        QVERIFY(json(QFileInfo(jar).absolutePath() + "/renamed-client.json", {{"id", "整合包-profile"}, {"clientVersion", "1.21.4"},
            {"mainClass", "net.fabricmc.loader.impl.launch.knot.KnotClient"}, {"javaVersion", QJsonObject{{"majorVersion", 21}}},
            {"downloads", QJsonObject{{"client", QJsonObject{{"sha1", fileHash(jar)}}}}},
            {"libraries", QJsonArray{
                QJsonObject{{"name", "example:core:1"}, {"downloads", QJsonObject{{"artifact", QJsonObject{
                    {"path", "example/core/1/core-1.jar"}, {"sha1", libraryHash}, {"url", "https://libraries.minecraft.net/example/core/1/core-1.jar"}}}}}},
                QJsonObject{{"name", "net.fabricmc:fabric-loader:1"}, {"downloads", QJsonObject{{"artifact", QJsonObject{
                    {"path", "net/fabricmc/loader/1/loader-1.jar"}, {"sha1", QString(40, 'd')}, {"url", "https://maven.fabricmc.net/loader.jar"}}}}}}}}}));
        const auto probe = inspectLocalInstallation(QFileInfo(jar).absolutePath(), {});
        QVERIFY2(probe["ok"].toBool(), qPrintable(probe["message"].toString()));
        QCOMPARE(probe["version"].toString(), "1.21.4");
        QCOMPARE(probe["profile"].toString(), "整合包-profile");
        QVariantMap options{{"source", "local"}, {"sourcePath", QFileInfo(jar).absolutePath()},
            {"itemsRoot", root + "/items"}, {"allowNetwork", false}, {"javaPath", root + "/missing-java"}};
        // Loader libraries are intentionally absent: only the base game is used.
        const auto missingJava = importGame(options, {}, [](int, const QString &) {});
        QVERIFY2(missingJava["message"].toString().contains("Java"), qPrintable(missingJava["message"].toString()));
        const auto reports = root + "/items/cache/reports/" + fileHash(jar) + "-client";
        QVERIFY(json(reports + "/items.json", {{"minecraft:air", 0}, {"minecraft:stone", 1}}));
        QVERIFY(json(reports + "/complete.json", {{"clientSha1", fileHash(jar)}, {"componentsVersion", 1}}));
        const auto imported = importGame(options, {}, [](int, const QString &) {});
        QVERIFY2(imported["ok"].toBool(), qPrintable(imported["message"].toString()));
        QCOMPARE(imported["gameVersion"].toString(), "1.21.4");
        QCOMPARE(imported["itemCount"].toInt(), 2);
        QVERIFY(!QFileInfo::exists(root + "/items/cache/manifest.json"));
    }
    void inheritedModpackAndPrismProfilesFindBaseClient() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const auto original = fixtureClient(root + "/game");
        const auto base = root + "/game/versions/1.21.4/1.21.4.jar";
        QVERIFY(QFile::rename(original, base));
        QVERIFY(json(root + "/game/versions/1.21.4/1.21.4.json", {{"id", "1.21.4"}}));
        const auto pack = root + "/game/versions/forge-profile";
        QVERIFY(json(pack + "/forge-profile.json", {{"id", "forge-profile"}, {"inheritsFrom", "1.21.4"}, {"mainClass", "cpw.mods.modlauncher.Launcher"}}));
        const auto result = inspectLocalInstallation(pack, {});
        QVERIFY2(result["ok"].toBool(), qPrintable(result["message"].toString()));
        QCOMPARE(result["version"].toString(), "1.21.4");
        QCOMPARE(result["clientJar"].toString(), base);
        QCOMPARE(result["profile"].toString(), "forge-profile");
        const auto prism = root + "/game/instances/prism-pack";
        QVERIFY(json(prism + "/mmc-pack.json", {{"components", QJsonArray{
            QJsonObject{{"uid", "net.minecraft"}, {"version", "1.21.4"}},
            QJsonObject{{"uid", "net.fabricmc.fabric-loader"}, {"version", "0.16.0"}}}}}));
        QCOMPARE(inspectLocalInstallation(prism, {})["clientJar"].toString(), base);
        QVERIFY(json(pack + "/forge-profile.json", {{"id", "forge-profile"}, {"inheritsFrom", "循环配置"}}));
        QVERIFY(json(root + "/game/versions/循环配置/循环配置.json", {{"id", "循环配置"}, {"inheritsFrom", "forge-profile"}}));
        QVERIFY(!inspectLocalInstallation(pack, {})["ok"].toBool());
    }
    void dependenciesAreCheckedBeforeJavaAndNeverTriggerServerDownload() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const auto jar = fixtureClient(root + "/game");
        QVERIFY(!jar.isEmpty());
        const QByteArray libraryBytes("verified library");
        const auto libraryHash = QString::fromLatin1(QCryptographicHash::hash(libraryBytes, QCryptographicHash::Sha1).toHex());
        QJsonObject artifact{{"path", "example/test/1/test-1.jar"}, {"sha1", libraryHash},
            {"url", "https://libraries.minecraft.net/example/test/1/test-1.jar"}};
        QJsonObject metadata{{"id", "1.21.4"}, {"downloads", QJsonObject{
            {"client", QJsonObject{{"sha1", fileHash(jar)}}},
            {"server", QJsonObject{{"sha1", QString(40, 'c')}, {"size", 1048576}, {"url", "https://piston-data.mojang.com/server.jar"}}}}}};
        const auto saveMetadata = [&] {
            metadata.insert("libraries", QJsonArray{
                QJsonObject{{"name", "skipped:library:1"}, {"rules", QJsonArray{QJsonObject{
                    {"action", "allow"}, {"os", QJsonObject{{"name", "nonexistent-os"}}}}}},
                    {"downloads", QJsonObject{{"artifact", QJsonObject{{"path", "../invalid.jar"}}}}}},
                QJsonObject{{"name", "example:test:1"}, {"downloads", QJsonObject{{"artifact", artifact}}}},
                QJsonObject{{"name", "example:duplicate:1"}, {"downloads", QJsonObject{{"artifact", artifact}}}}});
            return json(QFileInfo(jar).absolutePath() + "/renamed-client.json", metadata);
        };
        QVERIFY(saveMetadata());
        const QVariantMap options{{"itemsRoot", root + "/items"}, {"source", "local"}, {"sourcePath", jar},
            {"librariesPath", root + "/libs"}, {"allowNetwork", false}, {"javaPath", root + "/missing-java"}};
        const auto import = [&] { return importGame(options, {}, [](int, const QString &) {}); };
        auto result = import();
        QVERIFY(!result["ok"].toBool());
        QVERIFY2(result["message"].toString().contains("example/test/1/test-1.jar"), qPrintable(result["message"].toString()));
        QVERIFY(result["message"].toString().contains("1 个依赖"));
        QVERIFY(result["canUseServer"].toBool());
        QVERIFY(!QFileInfo::exists(root + "/items/cache/downloads/" + QString(40, 'c') + ".jar"));
        QVERIFY(bytes(root + "/libs/example/test/1/test-1.jar", "corrupt library"));
        QVERIFY(import()["message"].toString().contains("example/test/1/test-1.jar"));
        QVERIFY(bytes(root + "/libs/example/test/1/test-1.jar", libraryBytes));
        // Valid local dependencies are reused; Java is now the only missing input.
        result = import();
        QVERIFY2(result["message"].toString().contains("Java"), qPrintable(result["message"].toString()));
        artifact.insert("path", "../escape.jar");
        QVERIFY(saveMetadata());
        QVERIFY(import()["message"].toString().contains("无效的依赖路径"));
        QVERIFY(!QFileInfo::exists(root + "/items/cache/manifest.json"));
    }
    void serverReportsRequireExplicitFallback() {
        QTemporaryDir directory;
        const auto root = directory.path();
        const auto jar = fixtureClient(root + "/game");
        QVERIFY(!jar.isEmpty());
        const auto serverHash = QString(40, 'c');
        QVERIFY(json(QFileInfo(jar).absolutePath() + "/renamed-client.json", {{"id", "1.21.4"},
            {"downloads", QJsonObject{{"client", QJsonObject{{"sha1", fileHash(jar)}}},
                {"server", QJsonObject{{"sha1", serverHash}, {"size", 1048576}, {"url", "https://piston-data.mojang.com/server.jar"}}}}}}));
        const auto reports = root + "/items/cache/reports/" + serverHash;
        QVERIFY(json(reports + "/items.json", {{"minecraft:air", 0}, {"minecraft:stone", 1}}));
        QVERIFY(json(reports + "/complete.json", {{"serverSha1", serverHash}, {"componentsVersion", 1}}));
        QVariantMap options{{"itemsRoot", root + "/items"}, {"source", "local"}, {"sourcePath", jar},
            {"allowNetwork", false}, {"javaPath", root + "/missing-java"}};
        const auto normal = importGame(options, {}, [](int, const QString &) {});
        QVERIFY(!normal["ok"].toBool());
        QVERIFY(activePack(root + "/items").isEmpty());
        options.insert("generator", "server");
        const auto fallback = importGame(options, {}, [](int, const QString &) {});
        QVERIFY2(fallback["ok"].toBool(), qPrintable(fallback["message"].toString()));
        QCOMPARE(fallback["generator"].toString(), "server");
        QCOMPARE(fallback["serverSha1"].toString(), serverHash);
        QCOMPARE(fallback["itemCount"].toInt(), 2);
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
        const auto option = [&](const QString &name) { const int index = arguments.indexOf(name); return index >= 0 ? arguments.value(index + 1) : QString{}; };
        const auto local = option("--local");
        const auto result = importGame({{"version", arguments[2]}, {"itemsRoot", arguments[3]},
            {"source", local.isEmpty() ? "download" : "local"}, {"sourcePath", local},
            {"librariesPath", option("--libraries")}, {"allowNetwork", !arguments.contains("--offline")},
            {"generator", arguments.contains("--server") ? "server" : "client"},
            {"javaPath", arguments.value(4)}, {"rebuild", arguments.contains("--rebuild")}}, std::make_shared<std::atomic_bool>(false),
            [](int progress, const QString &message) { qInfo().noquote() << progress << message; });
        qInfo().noquote() << QJsonDocument::fromVariant(result).toJson(QJsonDocument::Compact);
        return result.value("ok").toBool() ? 0 : 1;
    }
    MinecraftImportTests tests;
    return QTest::qExec(&tests, argc, argv);
}
#include "MinecraftImportTests.moc"
