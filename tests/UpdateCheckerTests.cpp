#include "UpdateChecker.h"
#include "UpdateFeedFixture.h"
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class UpdateCheckerTests : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() { QCoreApplication::setApplicationVersion("0.1.0"); }

    void dismissalSurvivesRestartAndNewVersionRemindsAgain() {
        QTemporaryDir temp;
        QVERIFY(temp.isValid());
        UpdateFeedFixture feed;
        QVERIFY(feed.server.isListening());
        const auto path = temp.filePath("update-state.ini");
        {
            UpdateChecker checker(feed.url(), path);
            QSignalSpy reminders(&checker, &UpdateChecker::startupUpdateAvailable);
            QSignalSpy finished(&checker, &UpdateChecker::checkFinished);
            checker.check();
            checker.check(); // Concurrent requests are coalesced.
            QVERIFY(finished.wait());
            QCOMPARE(feed.requests, 1);
            QCOMPARE(reminders.count(), 1);
            QCOMPARE(checker.latestVersion(), "0.2.0");
            QVERIFY(checker.updateAvailable());
            checker.dismissVersion("0.3.0"); // Cannot accidentally dismiss a different version.
            QVERIFY(!QFile::exists(path));
            checker.dismissVersion("0.2.0");
        }
        UpdateChecker restarted(feed.url(), path);
        QSignalSpy reminders(&restarted, &UpdateChecker::startupUpdateAvailable);
        QSignalSpy finished(&restarted, &UpdateChecker::checkFinished);
        restarted.check();
        QVERIFY(finished.wait());
        QCOMPARE(reminders.count(), 0);
        QVERIFY(restarted.updateAvailable()); // The About badge remains available.
        QCOMPARE(restarted.latestVersion(), "0.2.0");
        feed.setVersion("0.3.0");
        restarted.check();
        QVERIFY(finished.wait());
        QCOMPARE(reminders.count(), 1);
        QCOMPARE(restarted.latestVersion(), "0.3.0");
    }

    void numericVersions_data() {
        QTest::addColumn<QString>("current");
        QTest::addColumn<QString>("remote");
        QTest::addColumn<bool>("available");
        QTest::newRow("equal") << "0.1.0" << "0.1.0" << false;
        QTest::newRow("older") << "0.2.0" << "0.1.0" << false;
        QTest::newRow("numeric") << "0.9.0" << "0.10.0" << true;
        QTest::newRow("major") << "0.99.0" << "1.0.0" << true;
        QTest::newRow("prerelease-tag") << "0.1.0" << "0.2.0-beta.1" << false;
        QTest::newRow("malformed") << "0.1.0" << "anything" << false;
        QTest::newRow("overflow") << "0.1.0" << "0.99999999999999999999.0" << false;
    }
    void numericVersions() {
        QFETCH(QString, current);
        QFETCH(QString, remote);
        QFETCH(bool, available);
        QCoreApplication::setApplicationVersion(current);
        QTemporaryDir temp;
        UpdateFeedFixture feed;
        feed.setVersion(remote);
        UpdateChecker checker(feed.url(), temp.filePath("state.ini"));
        QSignalSpy finished(&checker, &UpdateChecker::checkFinished);
        checker.check();
        QVERIFY(finished.wait());
        QCOMPARE(checker.updateAvailable(), available);
        QCoreApplication::setApplicationVersion("0.1.0");
    }

    void invalidResponses_data() {
        QTest::addColumn<int>("status");
        QTest::addColumn<QByteArray>("body");
        QTest::newRow("no-release") << 404 << QByteArray("{}");
        QTest::newRow("rate-limit") << 403 << QByteArray("{}");
        QTest::newRow("html") << 200 << QByteArray("<html>error</html>");
        QTest::newRow("array") << 200 << QByteArray("[]");
        QTest::newRow("missing-fields") << 200 << QByteArray("{\"tag_name\":\"v2.0.0\"}");
        UpdateFeedFixture feed;
        const auto release = QJsonDocument::fromJson(feed.body).object();
        for (const auto &field : {"draft", "prerelease"}) {
            auto value = release;
            value[field] = true;
            QTest::newRow(field) << 200 << QJsonDocument(value).toJson();
        }
        for (const auto &url : {"http://github.com/XCzongzi/xcshop/releases/tag/v0.2.0",
                                "https://evil.example/update", "https://github.com/other/repo/releases/tag/v0.2.0"}) {
            auto value = release;
            value["html_url"] = QString::fromLatin1(url);
            QTest::newRow(url) << 200 << QJsonDocument(value).toJson();
        }
        QTest::newRow("oversized") << 200 << QByteArray(600 * 1024, ' ');
    }
    void invalidResponses() {
        QFETCH(int, status);
        QFETCH(QByteArray, body);
        QTemporaryDir temp;
        UpdateFeedFixture feed;
        feed.status = status;
        feed.body = body;
        UpdateChecker checker(feed.url(), temp.filePath("state.ini"));
        QSignalSpy finished(&checker, &UpdateChecker::checkFinished);
        QSignalSpy reminders(&checker, &UpdateChecker::startupUpdateAvailable);
        checker.check();
        QVERIFY(finished.wait());
        QVERIFY(!checker.checking());
        QVERIFY(!checker.updateAvailable());
        QCOMPARE(reminders.count(), 0);
    }

    void timeout() {
        QTemporaryDir temp;
        UpdateFeedFixture feed;
        feed.stall = true;
        UpdateChecker checker(feed.url(), temp.filePath("state.ini"), 100);
        QSignalSpy finished(&checker, &UpdateChecker::checkFinished);
        checker.check();
        QVERIFY(finished.wait());
        QVERIFY(!checker.checking());
        QVERIFY(!checker.updateAvailable());
    }

    void cancelAllowsAnotherCheck() {
        QTemporaryDir temp;
        UpdateFeedFixture feed;
        feed.stall = true;
        UpdateChecker checker(feed.url(), temp.filePath("state.ini"));
        QSignalSpy finished(&checker, &UpdateChecker::checkFinished);
        QSignalSpy reminders(&checker, &UpdateChecker::startupUpdateAvailable);
        checker.check();
        QTRY_COMPARE(feed.requests, 1);
        checker.cancel();
        QTRY_COMPARE(finished.count(), 1);
        QVERIFY(!checker.checking());
        QVERIFY(!checker.updateAvailable());
        QCOMPARE(reminders.count(), 0);

        feed.stall = false;
        checker.check();
        QTRY_COMPARE(finished.count(), 2);
        QVERIFY(checker.updateAvailable());
        QCOMPARE(reminders.count(), 1);
    }
};

QTEST_GUILESS_MAIN(UpdateCheckerTests)
#include "UpdateCheckerTests.moc"
