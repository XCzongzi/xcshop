#include "MinecraftVersionCatalog.h"
#include "MinecraftDataPackVersions.h"
#include "UpdateFeedFixture.h"
#include <QtTest>
#include <QDateTime>
#include <QFile>
#include <QJsonArray>
#include <QSettings>
#include <QTemporaryDir>

namespace {
const auto successKey = QStringLiteral("versions/lastSuccessfulCheckMs");
QByteArray mapping(const QStringList &ids) {
    QJsonObject versions;
    for (const auto &id : ids) versions.insert(id, QJsonObject{{"major", 121}, {"minor", 0}});
    return QJsonDocument(QJsonObject{{"schemaVersion", 1}, {"versions", versions}}).toJson();
}
QByteArray manifest(const QString &latest) {
    return QJsonDocument(QJsonObject{{"latest", QJsonObject{{"release", latest}, {"snapshot", "26.4-snapshot-1"}}},
        {"versions", QJsonArray{QJsonObject{{"id", "26.4-snapshot-1"}, {"type", "snapshot"}},
                                QJsonObject{{"id", latest}, {"type", "release"}}}}}).toJson();
}
bool write(const QString &path, const QByteArray &bytes) {
    QFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size();
}
QByteArray read(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}
qint64 lastSuccess(const QString &path) { return QSettings(path, QSettings::IniFormat).value(successKey, 0).toLongLong(); }
}

class MinecraftVersionCatalogTests : public QObject {
    Q_OBJECT
private slots:
    void localCatalog() {
        QTemporaryDir dir;
        const auto path = dir.filePath("versions.json");
        QVERIFY(write(path, mapping({"26.10", "26.3", "1.21.11", "26.1.2"})));
        MinecraftVersionCatalog catalog(path, dir.filePath("state.ini"), {}, {});
        QCOMPARE(catalog.versions(), QStringList({"1.21.11", "26.1.2", "26.3", "26.10"}));
        QVERIFY(!catalog.checking());
        QVERIFY(write(path, "bad json"));
        catalog.reload();
        QVERIFY(catalog.versions().isEmpty());
    }
    void currentAndDailyCooldown() {
        QTemporaryDir dir;
        const auto path = dir.filePath("versions.json"), state = dir.filePath("state.ini");
        const auto bytes = mapping({"26.3", "1.21.11"});
        QVERIFY(write(path, bytes));
        UpdateFeedFixture mojang, downloads;
        mojang.body = manifest("26.3");
        MinecraftVersionCatalog catalog(path, state, mojang.url(), downloads.url());
        QSignalSpy finished(&catalog, &MinecraftVersionCatalog::checkFinished);
        catalog.checkForUpdates();
        catalog.checkForUpdates(); // Ignore duplicate calls while requesting.
        QTRY_COMPARE(finished.size(), 1);
        QVERIFY(finished.last()[0].toBool());
        QCOMPARE(mojang.requests, 1);
        QCOMPARE(downloads.requests, 0);
        QCOMPARE(read(path), bytes);
        QVERIFY(lastSuccess(state) > 0);
        MinecraftVersionCatalog restarted(path, state, mojang.url(), downloads.url());
        restarted.checkForUpdates();
        QVERIFY(!restarted.checking());
        QCOMPARE(mojang.requests, 1);
        QSettings settings(state, QSettings::IniFormat);
        settings.setValue(successKey, QDateTime::currentMSecsSinceEpoch() - 24LL * 60 * 60 * 1000 - 1000);
        settings.sync();
        restarted.checkForUpdates();
        QTRY_VERIFY(!restarted.checking());
        QCOMPARE(mojang.requests, 2);
        QCOMPARE(downloads.requests, 0);
    }
    void updateAndRepair() {
        for (const auto &initial : {mapping({"26.2"}), QByteArray("invalid"), QByteArray()}) {
            QTemporaryDir dir;
            const auto path = dir.filePath("versions.json"), state = dir.filePath("state.ini");
            if (!initial.isEmpty()) QVERIFY(write(path, initial));
            UpdateFeedFixture mojang, downloads;
            mojang.body = manifest("26.3");
            downloads.body = mapping({"26.3", "26.2"});
            MinecraftVersionCatalog catalog(path, state, mojang.url(), downloads.url());
            QSignalSpy finished(&catalog, &MinecraftVersionCatalog::checkFinished);
            QSignalSpy changed(&catalog, &MinecraftVersionCatalog::versionsChanged);
            catalog.checkForUpdates();
            QTRY_COMPARE(finished.size(), 1);
            QVERIFY(finished.last()[0].toBool());
            QCOMPARE(downloads.requests, 1);
            QCOMPARE(read(path), downloads.body);
            QCOMPARE(catalog.versions(), QStringList({"26.2", "26.3"}));
            QVERIFY(changed.size() >= 2);
            QVERIFY(lastSuccess(state) > 0);
        }
    }
    void failuresDoNotStartCooldown_data() {
        QTest::addColumn<QString>("mode");
        for (const auto &mode : {"manifest-http", "manifest-json", "manifest-no-latest", "manifest-snapshot",
                "manifest-timeout", "download-http", "download-json", "download-schema", "download-stale",
                "download-invalid-entry", "download-timeout", "write"})
            QTest::newRow(mode) << QString(mode);
    }
    void failuresDoNotStartCooldown() {
        QFETCH(QString, mode);
        QTemporaryDir dir;
        auto path = dir.filePath("versions.json");
        const auto state = dir.filePath("state.ini");
        const auto original = mapping({"26.2"});
        QVERIFY(write(path, original));
        UpdateFeedFixture mojang, downloads;
        mojang.body = manifest("26.3");
        downloads.body = mapping({"26.2", "26.3"});
        if (mode == "manifest-http") mojang.status = 503;
        if (mode == "manifest-json") mojang.body = "bad json";
        if (mode == "manifest-no-latest") mojang.body = "{\"versions\":[]}";
        if (mode == "manifest-snapshot") mojang.body = R"({"latest":{"release":"26.3"},"versions":[{"id":"26.3","type":"snapshot"}]})";
        if (mode == "manifest-timeout") mojang.stall = true;
        if (mode == "download-http") downloads.status = 404;
        if (mode == "download-json") downloads.body = "bad json";
        if (mode == "download-schema") downloads.body = R"({"schemaVersion":2,"versions":{"26.3":{"major":121,"minor":0}}})";
        if (mode == "download-stale") downloads.body = original;
        if (mode == "download-invalid-entry") downloads.body = R"({"schemaVersion":1,"versions":{"26.3":{"major":-1,"minor":0}}})";
        if (mode == "download-timeout") downloads.stall = true;
        if (mode == "write") path += "/versions.json"; // Parent is a file.
        MinecraftVersionCatalog catalog(path, state, mojang.url(), downloads.url(), 150);
        QSignalSpy finished(&catalog, &MinecraftVersionCatalog::checkFinished);
        catalog.checkForUpdates();
        QTRY_COMPARE(finished.size(), 1);
        QVERIFY(!finished.last()[0].toBool());
        QCOMPARE(lastSuccess(state), 0);
        QCOMPARE(read(dir.filePath("versions.json")), original);
        const auto firstRequests = mojang.requests;
        mojang.status = downloads.status = 200;
        mojang.stall = downloads.stall = false;
        mojang.body = manifest("26.3");
        downloads.body = mapping({"26.2", "26.3"});
        catalog.checkForUpdates();
        QTRY_COMPARE(finished.size(), 2);
        QCOMPARE(mojang.requests, firstRequests + 1);
        if (mode != "write") {
            QVERIFY(finished.last()[0].toBool());
            QVERIFY(lastSuccess(state) > 0);
        }
    }
};

QTEST_GUILESS_MAIN(MinecraftVersionCatalogTests)
#include "MinecraftVersionCatalogTests.moc"
