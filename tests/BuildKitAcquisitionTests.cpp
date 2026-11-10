#include "BuildKitManager.h"

#if QT_VERSION >= QT_VERSION_CHECK(6, 11, 0)
#include <QtCore/private/qzipwriter_p.h>
#else
#include <QtGui/private/qzipwriter_p.h>
#endif
#include <QtTest>
#include <QDirIterator>
#include <QDateTime>
#include <QSettings>
#include <QScopeGuard>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>

namespace {
const QString id = "89755dae-f798-440d-b3a9-342ee8a9070f";
QByteArray descriptor() {
    return (id + "\n0\n\"26.3\"...\n../blueprints/main.xcshoper\n../materials/alpha\n[\"测试套件\"]\n").toUtf8();
}
void writeKit(QZipWriter &zip, const QString &prefix = "kits/", const QByteArray &templateBytes = descriptor()) {
    zip.addFile(prefix + "templates/中文 空格.xcshopT", templateBytes);
    zip.addFile(prefix + "blueprints/main.xcshoper", "build \"sell.xcontent\"\n");
    zip.addFile(prefix + "materials/alpha/sell.xcontent", "sell.mcfunction\nsay test\n");
}
void makeZip(const QString &path, const QString &prefix = "kits/") {
    QZipWriter zip(path);
    writeKit(zip, prefix);
    zip.close();
}
QByteArray read(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}
bool write(const QString &path, const QByteArray &bytes) {
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) return false;
    QFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size();
}
class Feed : public QObject {
public:
    QTcpServer server;
    QByteArray body;
    int status = 200, requests = 0;
    bool stall = false;
    Feed() {
        server.listen(QHostAddress::LocalHost);
        connect(&server, &QTcpServer::newConnection, this, [this] {
            while (auto *socket = server.nextPendingConnection()) {
                connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
                connect(socket, &QTcpSocket::readyRead, socket, [this, socket] {
                    auto request = socket->property("request").toByteArray() + socket->readAll();
                    socket->setProperty("request", request);
                    if (!request.contains("\r\n\r\n") || socket->property("answered").toBool()) return;
                    socket->setProperty("answered", true);
                    ++requests;
                    if (stall) return;
                    socket->write("HTTP/1.1 " + QByteArray::number(status) + " Test\r\nContent-Length: "
                                  + QByteArray::number(body.size()) + "\r\nConnection: close\r\n\r\n" + body);
                    socket->disconnectFromHost();
                });
            }
        });
    }
    QUrl url() const { return QUrl(QString("http://127.0.0.1:%1/kits.zip").arg(server.serverPort())); }
};
}

class BuildKitAcquisitionTests : public QObject {
    Q_OBJECT
private slots:
    void onlineTemplateVersions_data() {
        QTest::addColumn<QByteArray>("newline");
        QTest::addColumn<bool>("bom");
        QTest::addColumn<QByteArray>("versions");
        QTest::newRow("lf-explicit") << QByteArray("\n") << false << QByteArray("\"26.3\",\"26.4\"");
        QTest::newRow("crlf-range") << QByteArray("\r\n") << false << QByteArray("\"26.3\",\"26.4\"...");
        QTest::newRow("bom-cr") << QByteArray("\r") << true << QByteArray("\"26.3\",\"26.4\"");
        QTest::newRow("bom-crlf") << QByteArray("\r\n") << true << QByteArray("\"26.3\",\"26.4\"...");
    }
    void onlineTemplateVersions() {
        QFETCH(QByteArray, newline);
        QFETCH(bool, bom);
        QFETCH(QByteArray, versions);
        QTemporaryDir temp;
        const auto archive = temp.filePath("local.zip");
        const auto base = descriptor() + "warning(\"保留检查代码\");\n";
        const auto format = [&](QByteArray bytes) {
            bytes.replace("\n", newline);
            return bom ? QByteArray("\xef\xbb\xbf") + bytes : bytes;
        };
        const auto original = format(base);
        { QZipWriter zip(archive); writeKit(zip, "kits/", original); zip.close(); }
        Feed feed;
        QVERIFY(feed.server.isListening());
        BuildKitManager kits(feed.url(), temp.filePath("state.ini"), 1);
        kits.setKitsPath(temp.filePath("target"));
        kits.setPreferredTemplateId(id);
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(archive);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY2(done[0][0].toBool(), qPrintable(done[0][1].toString()));
        const auto templatePath = kits.findTemplate(id)["path"].toString();
        QCOMPARE(read(templatePath), original);

        auto incoming = base;
        incoming.replace("\"26.3\"...", versions);
        { QZipWriter zip(archive); writeKit(zip, "kits/", incoming); zip.close(); }
        feed.body = read(archive);
        kits.acquire();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 2, 10000);
        QVERIFY2(done[1][0].toBool(), qPrintable(done[1][1].toString()));
        const auto expected = format(incoming);
        QCOMPARE(read(templatePath), expected);
        QCOMPARE(kits.findTemplate(id)["versions"].toStringList(), (QStringList{"26.3", "26.4"}));
        QCOMPARE(kits.findTemplate(id)["allowsNewer"].toBool(), versions.endsWith("..."));
        QCOMPARE(kits.versionSupport(id, "26.4"), 0);
        QCOMPARE(kits.versionSupport(id, "26.5"), versions.endsWith("...") ? 1 : -1);
        QCOMPARE(kits.preferredTemplateId(), id);
        QCOMPARE(read(kits.kitsPath() + "/materials/alpha/sell.xcontent"), QByteArray("sell.mcfunction\nsay test\n"));
        // Repeating an online update also works with a different source BOM/newline style.
        QTRY_COMPARE_WITH_TIMEOUT(kits.downloadCooldownSeconds(), 0, 3000);
        kits.acquire();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 3, 10000);
        QVERIFY2(done[2][0].toBool(), qPrintable(done[2][1].toString()));
        QCOMPARE(read(templatePath), expected);
    }
    void onlineTemplateVersionConflicts_data() {
        QTest::addColumn<QString>("change");
        for (const auto &change : {"body", "material", "id", "path", "invalid-version"})
            QTest::newRow(change) << QString(change);
    }
    void onlineTemplateVersionConflicts() {
        QFETCH(QString, change);
        QTemporaryDir temp;
        const auto archive = temp.filePath("kits.zip"); makeZip(archive);
        Feed feed;
        QVERIFY(feed.server.isListening());
        BuildKitManager kits(feed.url(), temp.filePath("state.ini"), 1);
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(archive);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY(done[0][0].toBool());
        const auto templatePath = kits.findTemplate(id)["path"].toString();
        const auto original = read(templatePath);
        auto incoming = descriptor();
        incoming.replace("\"26.3\"...", change == "invalid-version" ? "\"26.4\",\"26.3\"" : "\"26.4\"...");
        if (change == "body") incoming.append("error(\"changed\");\n");
        if (change == "id") incoming.replace(id.toUtf8(), "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
        {
            QZipWriter zip(archive);
            zip.addFile(change == "path" ? "kits/templates/renamed.xcshopT" : "kits/templates/中文 空格.xcshopT", incoming);
            zip.addFile("kits/blueprints/main.xcshoper", "build \"sell.xcontent\"\n");
            zip.addFile("kits/materials/alpha/sell.xcontent", change == "material" ? "changed" : "sell.mcfunction\nsay test\n");
            zip.addFile("kits/materials/alpha/new.xcontent", "new.mcfunction\nsay new\n");
            zip.close();
        }
        feed.body = read(archive);
        kits.acquire();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 2, 10000);
        QVERIFY2(!done[1][0].toBool(), qPrintable(change));
        QCOMPARE(read(templatePath), original);
        QVERIFY(!QFileInfo::exists(kits.kitsPath() + "/materials/alpha/new.xcontent"));
        QVERIFY(!QFileInfo::exists(kits.kitsPath() + "/templates/renamed.xcshopT"));
        QCOMPARE(kits.templates().size(), 1);
        QCOMPARE(kits.versionSupport(id, "26.3"), 0);
    }
    void onlineTemplateVersionWriteFailure() {
        QTemporaryDir temp;
        const auto archive = temp.filePath("kits.zip");
        const auto makeArchive = [&](bool update) {
            auto first = descriptor();
            if (update) first.replace("\"26.3\"...", "\"26.4\"...");
            auto second = first;
            second.replace(id.toUtf8(), "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
            QZipWriter zip(archive);
            zip.addFile("kits/templates/a.xcshopT", first);
            zip.addFile("kits/templates/z.xcshopT", second);
            zip.addFile("kits/blueprints/main.xcshoper", "build \"sell.xcontent\"\n");
            zip.addFile("kits/materials/alpha/sell.xcontent", "sell.mcfunction\nsay test\n");
            if (update) zip.addFile("kits/materials/alpha/new.xcontent", "new.mcfunction\nsay new\n");
            zip.close();
        };
        makeArchive(false);
        Feed feed;
        QVERIFY(feed.server.isListening());
        BuildKitManager kits(feed.url(), temp.filePath("state.ini"), 1);
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(archive);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY(done[0][0].toBool());
        const auto firstPath = kits.kitsPath() + "/templates/a.xcshopT";
        const auto secondPath = kits.kitsPath() + "/templates/z.xcshopT";
        const auto first = read(firstPath), second = read(secondPath);
        const auto permissions = QFileInfo(secondPath).permissions();
        const auto restore = qScopeGuard([&] { QFile::setPermissions(secondPath, permissions); });
        QVERIFY(QFile::setPermissions(secondPath, QFile::ReadOwner | QFile::ReadUser));
        makeArchive(true);
        feed.body = read(archive);
        kits.acquire();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 2, 10000);
        QVERIFY2(!done[1][0].toBool(), qPrintable(done[1][1].toString()));
        QVERIFY(done[1][1].toString().contains("无法更新模板"));
        QCOMPARE(read(firstPath), first);
        QCOMPARE(read(secondPath), second);
        QVERIFY(!QFileInfo::exists(kits.kitsPath() + "/materials/alpha/new.xcontent"));
        QCOMPARE(kits.versionSupport(id, "26.3"), 0);
    }
    void localTemplateVersionConflict_data() {
        QTest::addColumn<QString>("mode");
        for (const auto &mode : {"zip", "directory", "direct"})
            QTest::newRow(mode) << QString(mode);
    }
    void localTemplateVersionConflict() {
        QFETCH(QString, mode);
        QTemporaryDir temp;
        const auto archive = temp.filePath("kits.zip"); makeZip(archive);
        BuildKitManager kits;
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(archive);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY(done[0][0].toBool());
        auto incoming = descriptor();
        incoming.replace("\"26.3\"...", "\"26.4\"...");
        if (mode == "zip") {
            QZipWriter zip(archive); writeKit(zip, "kits/", incoming); zip.close();
            kits.acquire(archive);
        } else {
            const auto source = temp.filePath("source");
            QVERIFY(write(source + "/templates/中文 空格.xcshopT", incoming));
            QVERIFY(write(source + "/blueprints/main.xcshoper", "build \"sell.xcontent\"\n"));
            QVERIFY(write(source + "/materials/alpha/sell.xcontent", "sell.mcfunction\nsay test\n"));
            if (mode == "direct") QVERIFY(!kits.importKit(source).isEmpty());
            else kits.acquire(source);
        }
        if (mode != "direct") {
            QTRY_COMPARE_WITH_TIMEOUT(done.size(), 2, 10000);
            QVERIFY(!done[1][0].toBool());
        }
        QCOMPARE(read(kits.findTemplate(id)["path"].toString()), descriptor());
    }
    void zipImport_data() {
        QTest::addColumn<QString>("prefix");
        QTest::newRow("wrapped") << QString("kits/");
        QTest::newRow("contents") << QString();
    }
    void zipImport() {
        QFETCH(QString, prefix);
        QTemporaryDir temp;
        const auto path = temp.filePath("套件 空格.zip");
        makeZip(path, prefix);
        BuildKitManager kits;
        kits.setKitsPath(temp.filePath("new/deep/kits"));
        kits.setPreferredTemplateId(id);
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(QUrl::fromLocalFile(path).toString());
        QVERIFY(kits.acquiring());
        QVERIFY(kits.busy());
        const auto target = kits.kitsPath();
        kits.setKitsPath(temp.filePath("other"));
        QCOMPARE(kits.kitsPath(), target);
        QVERIFY(!kits.importKit(temp.path()).isEmpty());
        QVERIFY(!kits.removeTemplate(id).isEmpty());
        kits.setBusy(true);
        kits.setBusy(false); // Builder state cannot unlock an acquisition.
        QVERIFY(kits.busy());
        kits.acquire(path); // A repeated click cannot start another job.
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY2(done[0][0].toBool(), qPrintable(done[0][1].toString()));
        QVERIFY(!kits.busy());
        QCOMPARE(kits.acquisitionProgress(), 100);
        QCOMPARE(kits.options().size(), 1);
        QCOMPARE(kits.preferredTemplateId(), id);
        kits.acquire(path);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 2, 10000);
        QVERIFY(done[1][0].toBool());
        // Existing edits are retained and new files are not partially merged.
        QFile changed(target + "/materials/alpha/sell.xcontent");
        QVERIFY(changed.open(QIODevice::WriteOnly));
        changed.write("local edits"); changed.close();
        const auto update = temp.filePath("updated.zip");
        { QZipWriter zip(update); writeKit(zip); zip.addFile("kits/materials/alpha/new.xcontent", "new"); zip.close(); }
        kits.acquire(update);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 3, 10000);
        QVERIFY(!done[2][0].toBool());
        QCOMPARE(read(changed.fileName()), QByteArray("local edits"));
        QVERIFY(!QFileInfo::exists(target + "/materials/alpha/new.xcontent"));
        QCOMPARE(kits.templates().size(), 1);
    }
    void unsafeZip_data() {
        QTest::addColumn<QString>("name");
        for (const auto &name : {"../escape", "/escape", "kits/../../escape", "kits\\evil", "C:/escape",
                                 "kits/file:stream", "kits/NUL.txt", "kits/file.", "kits/a/./b"})
            QTest::newRow(name) << QString(name);
    }
    void unsafeZip() {
        QFETCH(QString, name);
        QTemporaryDir temp;
        const auto path = temp.filePath("bad.zip");
        { QZipWriter zip(path); writeKit(zip); zip.addFile(name, "bad"); zip.close(); }
        // QZipWriter normalizes Windows separators; restore the raw unsafe
        // filename in both headers so this tests the reader, not the writer.
        if (name.contains('\\')) {
            auto bytes = read(path);
            auto normalized = name; normalized.replace('\\', '/');
            bytes.replace(normalized.toUtf8(), name.toUtf8());
            QFile file(path); QVERIFY(file.open(QIODevice::WriteOnly)); file.write(bytes);
        }
        BuildKitManager kits;
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(path);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY(!done[0][0].toBool());
        QVERIFY(!QFileInfo::exists(kits.kitsPath()));
        QVERIFY(!QFileInfo::exists(temp.filePath("escape")));
    }
    void invalidZip_data() {
        QTest::addColumn<QString>("mode");
        for (const auto &mode : {"html", "empty", "link", "duplicate", "crc", "template", "truncated",
                                 "expansion-limit", "size-mismatch", "extra-data"})
            QTest::newRow(mode) << QString(mode);
    }
    void invalidZip() {
        QFETCH(QString, mode);
        QTemporaryDir temp;
        const auto path = temp.filePath("bad.zip");
        if (mode == "html") {
            QFile file(path); QVERIFY(file.open(QIODevice::WriteOnly)); file.write("<html>Unavailable</html>");
        } else if (mode == "truncated") {
            makeZip(path); QFile file(path); QVERIFY(file.open(QIODevice::ReadWrite)); QVERIFY(file.resize(32));
        } else if (mode == "expansion-limit" || mode == "size-mismatch" || mode == "extra-data") {
            makeZip(path);
            auto bytes = read(path);
            const auto central = bytes.indexOf(QByteArray("PK\1\2", 4)); QVERIFY(central >= 0);
            if (mode == "extra-data") bytes.append("invalid trailer");
            else {
                quint32 size = mode == "expansion-limit" ? 32 * 1024 * 1024 + 1 : 1;
                for (int i = 0; i < 4; ++i) bytes[central + 24 + i] = char(size >> (i * 8));
            }
            QFile file(path); QVERIFY(file.open(QIODevice::WriteOnly)); file.write(bytes);
        } else {
            QZipWriter zip(path);
            if (mode == "link") zip.addSymLink("kits/link", "../../outside");
            if (mode == "duplicate") { zip.addFile("kits/a", "one"); zip.addFile("kits/A", "two"); }
            if (mode == "template") zip.addFile("kits/templates/bad.xcshopT", "invalid template");
            if (mode == "crc") { zip.setCompressionPolicy(QZipWriter::NeverCompress); zip.addFile("kits/file", "unique-payload"); }
            zip.close();
            if (mode == "crc") {
                auto bytes = read(path); const auto offset = bytes.indexOf("unique-payload"); QVERIFY(offset >= 0);
                bytes[offset] = '!'; QFile file(path); QVERIFY(file.open(QIODevice::WriteOnly)); file.write(bytes);
            }
        }
        BuildKitManager kits;
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(path);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY2(!done[0][0].toBool(), qPrintable(mode));
        QVERIFY(!QFileInfo::exists(kits.kitsPath()));
    }
    void downloadRetryAndCancel() {
        QTemporaryDir temp;
        const auto archive = temp.filePath("kits.zip"); makeZip(archive);
        Feed feed;
        QVERIFY(feed.server.isListening());
        BuildKitManager kits(feed.url(), temp.filePath("download-state.ini"), 1000);
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        feed.status = 404; feed.body = "missing";
        kits.acquire();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY(!done[0][0].toBool());
        QVERIFY(!QFileInfo::exists(kits.kitsPath()));
        kits.acquire();
        QCOMPARE(done.size(), 2);
        QVERIFY(!done[1][0].toBool());
        QVERIFY(done[1][1].toString().contains("频繁"));
        QVERIFY(!kits.acquiring());
        QCOMPARE(feed.requests, 1);
        QTRY_COMPARE_WITH_TIMEOUT(kits.downloadCooldownSeconds(), 0, 3000);
        feed.status = 200; feed.stall = true;
        kits.acquire();
        QTRY_COMPARE(feed.requests, 2);
        kits.acquire(); // The in-flight guard also prevents duplicate downloads.
        QCOMPARE(done.size(), 2);
        kits.cancelAcquisition();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 3, 10000);
        QVERIFY(!done[2][0].toBool());
        QVERIFY(done[2][1].toString().contains("取消"));
        QVERIFY(!QFileInfo::exists(kits.kitsPath()));
        kits.acquire();
        QCOMPARE(done.size(), 4);
        QVERIFY(!done[3][0].toBool());
        QCOMPARE(feed.requests, 2);
        QTRY_COMPARE_WITH_TIMEOUT(kits.downloadCooldownSeconds(), 0, 3000);
        feed.stall = false; feed.body = read(archive);
        kits.acquire();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 5, 10000);
        QVERIFY2(done[4][0].toBool(), qPrintable(done[4][1].toString()));
        QCOMPARE(kits.options().size(), 1);
        kits.acquire();
        QCOMPARE(done.size(), 6);
        QVERIFY(!done[5][0].toBool());
        QCOMPARE(feed.requests, 3);
    }
    void downloadCooldownSurvivesRestart() {
        QTemporaryDir temp;
        const auto statePath = temp.filePath("download-state.ini");
        Feed feed;
        QVERIFY(feed.server.isListening());
        feed.status = 503; feed.body = "unavailable";
        {
            BuildKitManager kits(feed.url(), statePath);
            QCOMPARE(kits.downloadCooldownSeconds(), 0);
            QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
            kits.acquire();
            QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
            QVERIFY(!done[0][0].toBool());
            QVERIFY(kits.downloadCooldownSeconds() > 0);
            QVERIFY(kits.downloadCooldownSeconds() <= 60);
        }
        BuildKitManager restored(feed.url(), statePath);
        restored.setKitsPath(temp.filePath("target"));
        QVERIFY(restored.downloadCooldownSeconds() > 0);
        QVERIFY(restored.downloadCooldownSeconds() <= 60);
        QSignalSpy done(&restored, &BuildKitManager::acquisitionFinished);
        for (int i = 0; i < 5; ++i) restored.acquire();
        QCOMPARE(done.size(), 5);
        QCOMPARE(feed.requests, 1);
        QVERIFY(!restored.busy());
        // A download cooldown must not block either local import entry point.
        const auto archive = temp.filePath("kits.zip"); makeZip(archive);
        restored.acquire(archive);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 6, 10000);
        QVERIFY2(done[5][0].toBool(), qPrintable(done[5][1].toString()));
        const auto source = restored.kitsPath();
        restored.setKitsPath(temp.filePath("second-target"));
        restored.acquire(source);
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 7, 10000);
        QVERIFY2(done[6][0].toBool(), qPrintable(done[6][1].toString()));
        QCOMPARE(feed.requests, 1);
        QVERIFY(restored.downloadCooldownSeconds() > 0);
    }
    void restoredDownloadCooldown_data() {
        QTest::addColumn<qint64>("ageMs");
        QTest::addColumn<int>("expectedSeconds");
        QTest::newRow("expired") << qint64(61000) << 0;
        QTest::newRow("partly-elapsed") << qint64(30000) << 30;
        QTest::newRow("clock-moved-backwards") << qint64(-3600000) << 60;
    }
    void restoredDownloadCooldown() {
        QFETCH(qint64, ageMs);
        QFETCH(int, expectedSeconds);
        QTemporaryDir temp;
        const auto statePath = temp.filePath("download-state.ini");
        {
            QSettings state(statePath, QSettings::IniFormat);
            state.setValue("downloads/lastAttemptMs", QDateTime::currentMSecsSinceEpoch() - ageMs);
        }
        Feed feed;
        BuildKitManager kits(feed.url(), statePath);
        QVERIFY(kits.downloadCooldownSeconds() <= expectedSeconds);
        QVERIFY(kits.downloadCooldownSeconds() >= qMax(0, expectedSeconds - 1));
        if (expectedSeconds == 0) {
            feed.status = 503;
            QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
            kits.acquire();
            QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
            QCOMPARE(feed.requests, 1);
        }
    }
    void repositoryBundle() {
        QTemporaryDir temp;
        BuildKitManager kits;
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(QStringLiteral(XCSHOP_SOURCE_DIR) + "/kits.zip");
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY2(done[0][0].toBool(), qPrintable(done[0][1].toString()));
        QCOMPARE(kits.options(0).size(), 2);
        const QString r1 = "1fe54658-3cc3-4480-b943-f68d412fa421";
        QVERIFY(kits.findTemplate(r1)["valid"].toBool());
        QCOMPARE(kits.findTemplate(r1)["versions"].toStringList().size(), 11);
        QVERIFY(!kits.findTemplate(r1)["allowsNewer"].toBool());
        for (const auto &version : {"1.21.5", "1.21.8", "1.21.9", "1.21.11", "26.1.2", "26.2"})
            QCOMPARE(kits.versionSupport(r1, version), 0);
        for (const auto &version : {"1.21.4", "26.3", "26.4", "26.2-snapshot-1"})
            QCOMPARE(kits.versionSupport(r1, version), -1);
        QCOMPARE(kits.versionSupport("89755dae-f798-440d-b3a9-342ee8a9070f", "26.3"), 0);
    }
};
QTEST_GUILESS_MAIN(BuildKitAcquisitionTests)
#include "BuildKitAcquisitionTests.moc"
