#include "BuildKitManager.h"

#if QT_VERSION >= QT_VERSION_CHECK(6, 11, 0)
#include <QtCore/private/qzipwriter_p.h>
#else
#include <QtGui/private/qzipwriter_p.h>
#endif
#include <QtTest>
#include <QDirIterator>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>

namespace {
const QString id = "89755dae-f798-440d-b3a9-342ee8a9070f";
QByteArray descriptor() {
    return (id + "\n0\n\"26.3\"...\n../blueprints/main.xcshoper\n../materials/alpha\n[\"测试套件\"]\n").toUtf8();
}
void writeKit(QZipWriter &zip, const QString &prefix = "kits/") {
    zip.addFile(prefix + "templates/中文 空格.xcshopT", descriptor());
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
        BuildKitManager kits(feed.url());
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        feed.status = 404; feed.body = "missing";
        kits.acquire();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY(!done[0][0].toBool());
        QVERIFY(!QFileInfo::exists(kits.kitsPath()));
        feed.status = 200; feed.stall = true;
        kits.acquire();
        QTRY_COMPARE(feed.requests, 2);
        kits.cancelAcquisition();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 2, 10000);
        QVERIFY(!done[1][0].toBool());
        QVERIFY(done[1][1].toString().contains("取消"));
        QVERIFY(!QFileInfo::exists(kits.kitsPath()));
        feed.stall = false; feed.body = read(archive);
        kits.acquire();
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 3, 10000);
        QVERIFY2(done[2][0].toBool(), qPrintable(done[2][1].toString()));
        QCOMPARE(kits.options().size(), 1);
        QCOMPARE(feed.requests, 3);
    }
    void repositoryBundle() {
        QTemporaryDir temp;
        BuildKitManager kits;
        kits.setKitsPath(temp.filePath("target"));
        QSignalSpy done(&kits, &BuildKitManager::acquisitionFinished);
        kits.acquire(QStringLiteral(XCSHOP_SOURCE_DIR) + "/kits.zip");
        QTRY_COMPARE_WITH_TIMEOUT(done.size(), 1, 10000);
        QVERIFY2(done[0][0].toBool(), qPrintable(done[0][1].toString()));
        QVERIFY(!kits.options().isEmpty());
    }
};
QTEST_GUILESS_MAIN(BuildKitAcquisitionTests)
#include "BuildKitAcquisitionTests.moc"
