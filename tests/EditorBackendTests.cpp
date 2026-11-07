#include "BuildKitManager.h"
#include "BuildManager.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QDir>

static QString fixture;
static const QString templateId = "89755dae-f798-440d-b3a9-342ee8a9070f";
static bool writeFile(const QString &path, const QByteArray &bytes) {
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) return false;
    QFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size();
}
static bool makeKit(const QString &root, const QString &versions = "\"1.21.11\",\"26.1\",\"26.3\"...") {
    return writeFile(root + "/templates/nested/alpha.xcshopT", (templateId + "\n0\n" + versions
        + "\n../../blueprints/main.xcshoper\n../../materials/alpha\n[\n\"介绍包含 ] 与 \\\" 引号\",\"第二段\"\n]\nerror(\"此脚本不能在目录扫描时执行\");\n").toUtf8())
        && writeFile(root + "/blueprints/main.xcshoper", "build \"sell.xcontent\"\n")
        && writeFile(root + "/materials/alpha/sell.xcontent", "sell.mcfunction\nsay test\n");
}
static bool makeManifest(const QString &root, const QString &mode = "success") {
    QJsonObject project{{"name", "测试 output"}, {"generatePath", "../generated"}, {"fixtureMode", mode}};
    return writeFile(root + "/xcshop.json", QJsonDocument(project).toJson());
}

class EditorBackendTests : public QObject {
    Q_OBJECT
private slots:
    void catalog() {
        QTemporaryDir temp;
        QVERIFY(temp.isValid());
        QVERIFY(makeKit(temp.path()));
        BuildKitManager kits;
        kits.setKitsPath(temp.path());
        QVERIFY2(kits.issues().isEmpty(), qPrintable(kits.issues().join('\n')));
        QVERIFY(kits.identityValid());
        QCOMPARE(kits.templates().size(), 1);
        QCOMPARE(kits.dataVersion(), 0);
        QCOMPARE(kits.options(0).size(), 1);
        QCOMPARE(kits.options(1).size(), 0);
        QCOMPARE(kits.findTemplate(templateId)["introduction"].toStringList().size(), 2);
        QCOMPARE(kits.findTemplate(templateId)["materialCount"].toInt(), 1);
        QCOMPARE(kits.versionSupport(templateId, "26.3"), 0);
        QCOMPARE(kits.versionSupport(templateId, "26.10"), 1);
        QCOMPARE(kits.versionSupport(templateId, "26.4-rc1"), 1);
        QCOMPARE(kits.versionSupport(templateId, "1.21.12"), -1);
        QCOMPARE(kits.versionSupport(templateId, "26w12a"), -1);
        QVERIFY(QFile::rename(temp.path() + "/templates/nested/alpha.xcshopT", temp.path() + "/templates/nested/renamed.xcshopT"));
        kits.refresh();
        QCOMPARE(kits.findTemplate(templateId)["name"].toString(), "renamed");
        QCOMPARE(kits.localPath(QUrl::fromLocalFile(temp.path() + "/中文 空格").toString()), temp.path() + "/中文 空格");
    }
    void invalidCatalog() {
        QTemporaryDir temp;
        QVERIFY(makeKit(temp.path()));
        BuildKitManager kits;
        kits.setKitsPath(temp.path());
        QVERIFY(QFile::copy(temp.path() + "/templates/nested/alpha.xcshopT", temp.path() + "/templates/duplicate.xcshopT"));
        kits.refresh();
        QVERIFY(!kits.identityValid());
        QVERIFY(kits.options().isEmpty());
        QVERIFY(!kits.issues().isEmpty());
        QVERIFY(QFile::remove(temp.path() + "/templates/duplicate.xcshopT"));
        QVERIFY(writeFile(temp.path() + "/templates/bad.xcshopT", "not-an-id\n"));
        kits.refresh();
        QVERIFY(!kits.identityValid());
        QVERIFY(QFile::remove(temp.path() + "/templates/bad.xcshopT"));
        QVERIFY(QFile::remove(temp.path() + "/blueprints/main.xcshoper"));
        kits.refresh();
        QVERIFY(kits.identityValid());
        QVERIFY(kits.options().isEmpty());
        QVERIFY(!kits.findTemplate(templateId)["valid"].toBool());
    }
    void safeImport() {
        QTemporaryDir incoming, target;
        QVERIFY(makeKit(incoming.path()));
        BuildKitManager kits;
        kits.setKitsPath(target.path());
        QCOMPARE(kits.importKit(incoming.path()), QString());
        QCOMPARE(kits.templates().size(), 1);
        QCOMPARE(kits.importKit(incoming.path()), QString()); // Identical files may be shared.
        QVERIFY(writeFile(incoming.path() + "/materials/alpha/sell.xcontent", "different"));
        QVERIFY(writeFile(incoming.path() + "/materials/alpha/new.xcontent", "new"));
        QVERIFY(!kits.importKit(incoming.path()).isEmpty());
        QVERIFY(!QFile::exists(target.path() + "/materials/alpha/new.xcontent"));
        kits.setBusy(true);
        const auto path = kits.kitsPath();
        kits.setKitsPath(incoming.path());
        QCOMPARE(kits.kitsPath(), path);
        QVERIFY(!kits.removeTemplate(templateId).isEmpty());
        QVERIFY(!kits.importKit(incoming.path()).isEmpty());
    }
    void versionInfo_data() {
        QTest::addColumn<QString>("mode");
        QTest::addColumn<QString>("expected");
        QTest::newRow("stdout") << QString() << QString("路径无效：未获取到有效版本信息。");
        QTest::newRow("stderr") << QString("stderr") << QString("路径无效：未获取到有效版本信息。");
        QTest::newRow("invalid-json") << QString("invalid-json") << QString("路径无效：未获取到有效版本信息。");
        QTest::newRow("json") << QString("json") << QString("{\"builderVersion\":\"0.1.0\",\"protocolVersion\":0,\"maxSupportedDataVersion\":0}");
        QTest::newRow("empty") << QString("empty") << QString("路径无效：未返回版本信息。");
        QTest::newRow("error") << QString("error") << QString("路径无效：获取版本失败（退出码 2）。");
        QTest::newRow("timeout") << QString("slow") << QString("路径无效：获取版本超时。");
    }
    void versionInfo() {
        QFETCH(QString, mode);
        QFETCH(QString, expected);
        qputenv("XCSHOP_FIXTURE_VERSION_MODE", mode.toUtf8());
        BuildManager builder;
        builder.setExecutablePath(fixture);
        builder.fetchVersion();
        qunsetenv("XCSHOP_FIXTURE_VERSION_MODE");
        QVERIFY(builder.queryingVersion());
        builder.fetchVersion(); // Ignore repeated requests while a query is running.
        QTRY_VERIFY_WITH_TIMEOUT(!builder.queryingVersion(), 8000);
        QCOMPARE(builder.versionInfo(), expected);
        QCOMPARE(builder.versionValid(), mode == "json");
        if (mode == "json")
            QCOMPARE(builder.displayVersionInfo(), QString("版本：0.1.0\n最高支持数据版本：0"));
        else
            QCOMPARE(builder.displayVersionInfo(), expected);
        BuildManager restored;
        restored.setExecutablePath(fixture);
        restored.restoreVersionInfo(fixture, builder.versionInfo());
        QCOMPARE(restored.versionInfo(), expected);
        QCOMPARE(restored.displayVersionInfo(), builder.displayVersionInfo());
        QCOMPARE(restored.versionValid(), builder.versionValid());
        restored.recheckExecutable();
        restored.setExecutablePath(fixture);
        QCOMPARE(restored.versionInfo(), expected);
        restored.restoreVersionInfo(fixture + ".different", "stale version");
        QCOMPARE(restored.versionInfo(), expected);
        QVERIFY(!builder.running());
        QVERIFY(builder.consoleText().isEmpty());
        builder.setExecutablePath(fixture + ".missing");
        QVERIFY(builder.versionInfo().isEmpty());
        builder.fetchVersion();
        QVERIFY(!builder.queryingVersion());
        QVERIFY(builder.versionInfo().contains("不可用"));
    }
    void process_data() {
        QTest::addColumn<QString>("mode");
        QTest::addColumn<bool>("success");
        for (const auto &mode : {"success", "error", "missing", "malformed", "unsupported", "duplicate", "exit", "crash", "large", "arguments", "invalid-mode", "invalid-output", "missing-mode", "missing-output"})
            QTest::newRow(mode) << QString(mode) << (QString(mode) == "success" || QString(mode) == "large" || QString(mode) == "arguments");
    }
    void process() {
        QFETCH(QString, mode);
        QFETCH(bool, success);
        QTemporaryDir temp;
        const auto project = temp.path() + "/项目 with spaces";
        QVERIFY(makeManifest(project, mode));
        QVERIFY(makeKit(temp.path() + "/kits"));
        BuildManager builder;
        builder.setExecutablePath(fixture);
        QVERIFY(builder.available());
        if (mode == "arguments") builder.setStartupArguments("--label \"中文 with spaces\" --verbose");
        QSignalSpy finished(&builder, &BuildManager::completed);
        QVERIFY(builder.start(project, temp.path() + "/kits"));
        QVERIFY(!builder.start(project, temp.path() + "/kits"));
        QTRY_COMPARE_WITH_TIMEOUT(finished.size(), 1, 10000);
        QCOMPARE(finished[0][0].toBool(), success);
        QVERIFY(!builder.running());
        if (mode == "success" || mode == "error") {
            QVERIFY(builder.consoleText().contains("日志：中文路径与空格"));
            QCOMPARE(builder.result()["protocol"].toString(), "xcshop-builder/result");
            QCOMPARE(builder.problems().size(), 1);
            QCOMPARE(builder.problems()[0].toMap()["property"].toString(), "$.operations[0].cost[0].amount");
            QCOMPARE(builder.problems()[0].toMap()["solution"].toString(), "请修改原始属性");
        }
        if (mode == "error") {
            QVERIFY(makeManifest(project));
            QVERIFY(builder.start(project, temp.path() + "/kits"));
            QTRY_COMPARE_WITH_TIMEOUT(finished.size(), 2, 10000);
            QVERIFY(finished[1][0].toBool());
        }
        if (mode == "large") QVERIFY(builder.consoleText().size() <= 256 * 1024);
        QCOMPARE(builder.outputPath(), temp.path() + "/generated/测试 output");
    }
    void checkOnlyResults() {
        QTemporaryDir temp;
        const auto project = temp.path() + "/project";
        QVERIFY(makeKit(temp.path() + "/kits"));
        BuildManager builder;
        builder.setExecutablePath(fixture);
        for (const auto &mode : {"check", "check-error", "no-output", "written"}) {
            const bool checkOnly = QString(mode).startsWith("check");
            const bool success = QString(mode) != "check-error";
            QVERIFY(makeManifest(project, mode));
            builder.setStartupArguments(checkOnly ? "--check" : "");
            QSignalSpy finished(&builder, &BuildManager::completed);
            QVERIFY(builder.start(project, temp.path() + "/kits"));
            QTRY_COMPARE_WITH_TIMEOUT(finished.size(), 1, 10000);
            QCOMPARE(finished[0][0].toBool(), success);
            QCOMPARE(builder.state(), checkOnly ? (success ? "检查通过" : "检查失败") : "构建成功");
            if (QString(mode) == "written") {
                QCOMPARE(builder.summary(), "数据包已生成");
                QVERIFY(!builder.outputPath().isEmpty());
            } else {
                QVERIFY(!builder.summary().contains("已生成"));
                QVERIFY(builder.outputPath().isEmpty());
            }
        }
    }
    void customOutputFolder() {
        QTemporaryDir temp;
        const auto project = temp.path() + "/project";
        QVERIFY(makeKit(temp.path() + "/kits"));
        BuildManager builder;
        builder.setExecutablePath(fixture);
        QCOMPARE(builder.resolveOutputPath(project, "../generated", "独立 文件夹"),
                 temp.path() + "/generated/独立 文件夹");
        for (const auto &folder : {QString("独立 文件夹"), QString()}) {
            QJsonObject data{{"name", "测试 output"}, {"generatePath", "../generated"}, {"outputFolder", folder}};
            QVERIFY(writeFile(project + "/xcshop.json", QJsonDocument(data).toJson()));
            QVERIFY(builder.start(project, temp.path() + "/kits"));
            QTRY_VERIFY_WITH_TIMEOUT(!builder.running(), 10000);
            QCOMPARE(builder.outputPath(), temp.path() + "/generated/" + (folder.isEmpty() ? QString("测试 output") : folder));
        }
    }
    void cancellationAndMissingProgram() {
        QTemporaryDir temp;
        QVERIFY(makeManifest(temp.path() + "/project", "slow"));
        QVERIFY(makeKit(temp.path() + "/kits"));
        BuildManager builder;
        builder.setExecutablePath(fixture);
        QSignalSpy finished(&builder, &BuildManager::completed);
        QVERIFY(builder.start(temp.path() + "/project", temp.path() + "/kits"));
        builder.cancel();
        QTRY_COMPARE_WITH_TIMEOUT(finished.size(), 1, 5000);
        QCOMPARE(builder.state(), "已取消");
        builder.setExecutablePath(temp.path() + "/missing.exe");
        QVERIFY(!builder.start(temp.path() + "/project", temp.path() + "/kits"));
        QVERIFY(!builder.running());
        QCOMPARE(finished.size(), 2);
    }
};

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    fixture = app.arguments().value(1);
    EditorBackendTests tests;
    auto report = app.arguments().value(2, "-,txt").toLocal8Bit();
    char option[] = "-o";
    char *testArguments[] = {argv[0], option, report.data()};
    return QTest::qExec(&tests, 3, testArguments);
}
#include "EditorBackendTests.moc"
