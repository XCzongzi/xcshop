#include <QCoreApplication>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QThread>
#include <cstdio>
#include <cstdlib>

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    const auto arguments = app.arguments();
    if (arguments.contains("--version")) {
        const auto mode = qEnvironmentVariable("XCSHOP_FIXTURE_VERSION_MODE");
        if (mode == "slow") QThread::msleep(10000);
        if (mode == "empty") return 0;
        if (mode == "error") { std::fputs("unsupported option\n", stderr); return 2; }
        if (mode == "invalid-json") {
            std::fputs("{\"builderVersion\":\"\",\"protocolVersion\":0,\"maxSupportedDataVersion\":0}\n", stdout);
            return 0;
        }
        if (mode == "json") {
            std::fputs("{\"builderVersion\":\"0.1.0\",\"protocolVersion\":0,\"maxSupportedDataVersion\":0}\n", stdout);
            return 0;
        }
        const auto version = QString("xcshop-builder 0.1.0\n构建器版本信息\n").toUtf8();
        auto *channel = mode == "stderr" ? stderr : stdout;
        std::fwrite(version.data(), 1, version.size(), channel);
        return 0;
    }
    const int index = arguments.indexOf("--project");
    if (index < 0 || index + 1 >= arguments.size() || !arguments.contains("--kits")) return 9;
    QFile manifest(arguments[index + 1] + "/xcshop.json");
    if (!manifest.open(QIODevice::ReadOnly)) return 10;
    const auto mode = QJsonDocument::fromJson(manifest.readAll()).object()["fixtureMode"].toString();
    if (mode == "arguments") {
        const auto label = arguments.indexOf("--label");
        if (label < 0 || arguments.value(label + 1) != "中文 with spaces" || !arguments.contains("--verbose")) return 11;
    }
    if (mode == "slow") QThread::msleep(10000);
    if (mode == "crash") std::abort();
    if (mode == "missing") { std::fputs("no result\n", stdout); return 1; }
    if (mode == "malformed") { std::fputs("XCSHOP_BUILD_RESULT {}\n", stdout); return 0; }
    const bool failed = mode == "error" || mode == "check-error";
    QJsonObject problem{{"file", arguments[index + 1] + "/Item/物品.xcseItem"},
        {"property", "$.operations[0].cost[0].amount"}, {"reason", "测试中文错误/警告"}, {"solution", "请修改原始属性"}, {"terminatesBuild", failed}};
    QJsonObject result{{"protocol", "xcshop-builder/result"}, {"version", mode == "unsupported" ? 2 : 0},
        {"builderVersion", "0.1.0"}, {"maxSupportedDataVersion", 0},
        {"buildEndedNormally", !failed}, {"buildSucceeded", !failed}, {"terminatedEarly", failed},
        {"errorCount", failed ? 1 : 0}, {"errors", failed ? QJsonArray{problem} : QJsonArray{}},
        {"warningCount", failed ? 0 : 1}, {"warnings", failed ? QJsonArray{} : QJsonArray{problem}}, {"internalError", QJsonValue::Null}};
    if (mode == "check" || mode == "check-error" || mode == "no-output" || mode == "written") {
        result["mode"] = mode.startsWith("check") ? "check" : "build";
        result["outputWritten"] = mode == "written";
    }
    if (mode == "invalid-mode") result["mode"] = "unknown";
    if (mode == "invalid-output") result["outputWritten"] = "true";
    if (mode == "large") {
        const QByteArray line(1024, 'a');
        for (int n = 0; n < 400; ++n) { std::fwrite(line.data(), 1, line.size(), stdout); std::fputc('\n', stdout); }
    }
    // Split both a UTF-8 codepoint and the machine result across writes.
    const auto log = QString("日志：中文路径与空格\n").toUtf8();
    std::fwrite(log.data(), 1, 2, stdout); std::fflush(stdout);
    QThread::msleep(10);
    std::fwrite(log.data() + 2, 1, log.size() - 2, stdout);
    std::fputs("XCSHOP_BUILD_RESULT {}\n", stderr); // stderr must not be interpreted as a result.
    const QByteArray record = "XCSHOP_BUILD_RESULT " + QJsonDocument(result).toJson(QJsonDocument::Compact);
    std::fwrite(record.data(), 1, 27, stdout); std::fflush(stdout);
    QThread::msleep(10);
    std::fwrite(record.data() + 27, 1, record.size() - 27, stdout);
    if (mode == "duplicate") { std::fputc('\n', stdout); std::fwrite(record.data(), 1, record.size(), stdout); }
    // Deliberately no trailing newline: finished() must flush the final buffered record.
    return failed || mode == "exit" ? 1 : 0;
}
