#include "BuildManager.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

namespace {
constexpr auto resultPrefix = "XCSHOP_BUILD_RESULT ";
constexpr qsizetype maxLineBytes = 8 * 1024 * 1024;
constexpr qsizetype maxConsoleChars = 256 * 1024;
QString absolutePath(const QString &value) {
    const QUrl url(value);
    const auto text = url.isLocalFile() ? url.toLocalFile() : value.trimmed();
    return text.isEmpty() ? QString() : QDir::cleanPath(QFileInfo(text).absoluteFilePath());
}
bool validVersionInfo(const QString &info) {
    const auto document = QJsonDocument::fromJson(info.toUtf8());
    if (!document.isObject()) return false;
    const auto object = document.object();
    if (!object["builderVersion"].isString() || object["builderVersion"].toString().trimmed().isEmpty()) return false;
    for (const auto &key : {"protocolVersion", "maxSupportedDataVersion"}) {
        const auto value = object[key];
        if (!value.isDouble() || value.toInt(-1) < 0 || value.toDouble() != value.toInt(-1)) return false;
    }
    return true;
}
bool validProtocol(const QJsonObject &object) {
    if (object["protocol"] != "xcshop-builder/result" || object["version"].toInt(-1) != 0) return false;
    for (const auto &name : {"buildEndedNormally", "buildSucceeded", "terminatedEarly"})
        if (!object[name].isBool()) return false;
    if (object["mode"] != "check" && object["mode"] != "build") return false;
    if (!object["outputWritten"].isBool()) return false;
    if (!object["internalError"].isNull() && !object["internalError"].isString()) return false;
    for (const auto &name : {"errors", "warnings"}) {
        if (!object[name].isArray()) return false;
        const auto array = object[name].toArray();
        const auto count = object[QString(name) == "errors" ? "errorCount" : "warningCount"];
        if (!count.isDouble() || count.toDouble() != double(array.size())) return false;
        for (const auto &value : array) {
            if (!value.isObject()) return false;
            const auto problem = value.toObject();
            for (const auto &key : {"file", "property", "reason", "solution"})
                if (!problem[key].isString()) return false;
            if (!problem["terminatesBuild"].isBool()) return false;
        }
    }
    return true;
}
}

BuildManager::BuildManager(QObject *parent) : QObject(parent), m_executablePath(defaultExecutablePath()) {
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
    m_versionProcess.setProcessChannelMode(QProcess::MergedChannels);
#ifdef Q_OS_WIN
    m_process.setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments *arguments) {
        arguments->flags |= 0x08000000; // CREATE_NO_WINDOW, no console flashes in the editor.
    });
    m_versionProcess.setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments *arguments) {
        arguments->flags |= 0x08000000;
    });
#endif
    m_versionTimer.setSingleShot(true);
    m_versionTimer.setInterval(5000);
    connect(&m_versionProcess, &QProcess::readyReadStandardOutput, this, [this] {
        const auto output = m_versionProcess.readAllStandardOutput();
        m_versionOutput += output.left(qMax<qsizetype>(0, 64 * 1024 - m_versionOutput.size()));
    });
    connect(&m_versionTimer, &QTimer::timeout, this, [this] {
        m_versionInfo = "路径无效：获取版本超时。";
        m_versionProcess.kill();
    });
    connect(&m_versionProcess, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart) return;
        m_versionTimer.stop();
        m_versionInfo = "路径无效：无法启动构建器。";
        m_queryingVersion = false;
        emit versionInfoChanged();
        emit versionInfoFetched();
    });
    connect(&m_versionProcess, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus status) {
        m_versionTimer.stop();
        const auto remaining = m_versionProcess.readAllStandardOutput();
        m_versionOutput += remaining.left(qMax<qsizetype>(0, 64 * 1024 - m_versionOutput.size()));
        const auto output = QString::fromUtf8(m_versionOutput).replace("\r\n", "\n").trimmed();
        if (m_versionInfo.isEmpty()) {
            if (status != QProcess::NormalExit || exitCode != 0)
                m_versionInfo = "路径无效：获取版本失败（退出码 " + QString::number(exitCode) + "）。";
            else
                m_versionInfo = validVersionInfo(output) ? output
                    : output.isEmpty() ? "路径无效：未返回版本信息。" : "路径无效：未获取到有效版本信息。";
        }
        m_queryingVersion = false;
        emit versionInfoChanged();
        emit versionInfoFetched();
    });
    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this] { readChannel(false); });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] { readChannel(true); });
    connect(&m_process, &QProcess::started, this, [this] {
        const bool checkOnly = m_process.arguments().contains("--check");
        m_state = m_cancelled ? "正在取消" : checkOnly ? "检查中" : "构建中";
        m_summary = checkOnly ? "正在检查项目" : "正在检查项目并生成数据包";
        if (m_cancelled) m_process.terminate();
        emit changed();
    });
    connect(&m_process, &QProcess::finished, this, &BuildManager::finish);
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart) return; // Crash is finalized by finished().
        integrationError("无法启动构建器：" + m_process.errorString(), "请在设置 → 构建器中选择有效的可执行文件，并检查权限与运行库。");
        m_elapsed = m_clock.elapsed();
        m_tick.stop();
        m_killTimer.stop();
        setRunning(false);
        m_state = "启动失败";
        emit changed();
        emit completed(false);
    });
    m_tick.setInterval(250);
    connect(&m_tick, &QTimer::timeout, this, &BuildManager::changed);
    m_killTimer.setSingleShot(true);
    m_killTimer.setInterval(2000);
    connect(&m_killTimer, &QTimer::timeout, this, [this] {
        if (m_running && m_cancelled) m_process.kill();
    });
}
BuildManager::~BuildManager() {
    if (m_versionProcess.state() != QProcess::NotRunning) m_versionProcess.kill();
    if (m_process.state() != QProcess::NotRunning) m_process.kill();
}
QString BuildManager::defaultExecutablePath() const {
#ifdef Q_OS_WIN
    return QCoreApplication::applicationDirPath() + "/builder/xcshop-builder-0.1.3.exe";
#else
    return QCoreApplication::applicationDirPath() + "/builder/xcshop-builder-0.1.3";
#endif
}
bool BuildManager::available() const {
    const QFileInfo info(m_executablePath);
    return info.isFile() && info.isExecutable();
}
void BuildManager::setExecutablePath(const QString &path) {
    if (m_running || m_queryingVersion) return;
    const auto next = absolutePath(path);
    if (m_executablePath == next) return;
    m_executablePath = next;
    m_versionInfo.clear();
    emit versionInfoChanged();
    emit executablePathChanged();
}
void BuildManager::setStartupArguments(const QString &arguments) {
    if (m_running || m_startupArguments == arguments) return;
    m_startupArguments = arguments;
    emit startupArgumentsChanged();
}
QString BuildManager::displayVersionInfo() const {
    const auto document = QJsonDocument::fromJson(m_versionInfo.toUtf8());
    if (!document.isObject()) return m_versionInfo;
    const auto object = document.object();
    QStringList details;
    if (object["builderVersion"].isString())
        details << "版本：" + object["builderVersion"].toString();
    if (object["maxSupportedDataVersion"].isDouble())
        details << "最高支持数据版本：" + QString::number(object["maxSupportedDataVersion"].toInt());
    return details.isEmpty() ? m_versionInfo : details.join('\n');
}
bool BuildManager::versionValid() const { return validVersionInfo(m_versionInfo); }
void BuildManager::restoreVersionInfo(const QString &path, const QString &info) {
    if (m_queryingVersion || absolutePath(path) != m_executablePath) return;
    m_versionInfo = info;
    emit versionInfoChanged();
}
void BuildManager::fetchVersion() {
    if (m_running || m_queryingVersion) return;
    m_versionInfo.clear();
    if (!available()) {
        m_versionInfo = "路径无效：构建器不可用。";
        emit versionInfoChanged();
        emit versionInfoFetched();
        return;
    }
    m_versionOutput.clear();
    m_queryingVersion = true;
    emit versionInfoChanged();
    m_versionProcess.setWorkingDirectory(QFileInfo(m_executablePath).absolutePath());
    m_versionTimer.start();
    m_versionProcess.start(m_executablePath, {"--version"}, QIODevice::ReadOnly);
}
void BuildManager::recheckExecutable() { emit executablePathChanged(); }
void BuildManager::setRunning(bool value) {
    if (m_running == value) return;
    m_running = value;
    emit runningChanged(value);
    emit changed();
}
void BuildManager::appendLog(const QString &text) {
    m_console += text + '\n';
    if (m_console.size() > maxConsoleChars) {
        m_console.remove(0, m_console.size() - maxConsoleChars);
        const auto newline = m_console.indexOf('\n');
        if (newline >= 0) m_console.remove(0, newline + 1);
    }
}
void BuildManager::integrationError(const QString &reason, const QString &solution) {
    m_summary = reason;
    m_problems << QVariantMap{{"severity", "error"}, {"code", "E_BUILDER"}, {"message", reason},
        {"reason", reason}, {"solution", solution}, {"file", m_executablePath}, {"property", "$builder"}, {"terminatesBuild", true}};
    appendLog("[编辑器] " + reason);
    m_state = "构建失败";
}
QString BuildManager::resolveOutputPath(const QString &project, const QString &parentPath,
                                       const QString &folderName) const {
    if (project.isEmpty() || parentPath.isEmpty()) return {};
    return QDir::cleanPath(QDir(QDir(absolutePath(project)).absoluteFilePath(parentPath)).filePath(folderName));
}

bool BuildManager::start(const QString &project, const QString &kits) {
    if (m_running || m_queryingVersion) return false;
    m_projectPath = absolutePath(project);
    const auto startupArguments = QProcess::splitCommand(m_startupArguments);
    const bool checkOnly = startupArguments.contains("--check");
    m_outputPath.clear();
    m_console.clear();
    m_problems.clear();
    m_result.clear();
    m_stdout.clear();
    m_stderr.clear();
    m_discardStdout = m_discardStderr = false;
    m_protocolError.clear();
    m_receivedResult = m_cancelled = false;
    m_elapsed = 0;
    m_summary.clear();
    m_clock.start();
    recheckExecutable();
    QString error;
    if (!available()) error = "构建器路径不存在或不是可执行文件。";
    const auto kitsPath = absolutePath(kits);
    if (!QFileInfo(QDir(kitsPath).filePath("templates")).isDir()) error = "构建套件目录下缺少 templates 文件夹。";
    QFile manifest(QDir(m_projectPath).filePath("xcshop.json"));
    if (m_projectPath.isEmpty() || !manifest.open(QIODevice::ReadOnly)) error = "无法读取项目的 xcshop.json。";
    else {
        const auto document = QJsonDocument::fromJson(manifest.readAll());
        if (!document.isObject()) error = "项目的 xcshop.json 不是有效的 JSON 对象。";
        else {
            const auto data = document.object();
            // Actual semantic validation belongs to the builder. Only derive a display path here.
            const auto output = data["generatePath"].toString();
            const auto name = data["outputFolder"].toString().isEmpty()
                    ? data["name"].toString() : data["outputFolder"].toString();
            if (!checkOnly && !output.isEmpty() && !name.isEmpty())
                m_outputPath = resolveOutputPath(m_projectPath, output, name);
        }
    }
    if (!error.isEmpty()) {
        integrationError(error, "请检查设置中的构建器、构建套件目录和当前项目配置后重试。");
        emit changed();
        emit completed(false);
        return false;
    }
    m_state = "正在启动";
    m_summary = "正在启动构建器";
    appendLog("[编辑器] 项目：" + m_projectPath);
    appendLog("[编辑器] 套件：" + kitsPath);
    m_process.setWorkingDirectory(m_projectPath);
    // No shell and no hand-built quoting: spaces and Chinese paths remain separate arguments.
    setRunning(true);
    m_tick.start();
    QStringList arguments{"--project", m_projectPath, "--kits", kitsPath};
    arguments.append(startupArguments);
    m_process.start(m_executablePath, arguments, QIODevice::ReadOnly);
    return true;
}
void BuildManager::cancel() {
    if (!m_running || m_cancelled) return;
    m_cancelled = true;
    m_state = "正在取消";
    m_summary = "正在停止构建进程";
    appendLog("[编辑器] 请求停止构建；若已进入写入阶段，请在下一次构建后检查输出。");
    m_process.terminate();
    m_killTimer.start();
    emit changed();
}
void BuildManager::readChannel(bool standardError, bool flush) {
    auto &buffer = standardError ? m_stderr : m_stdout;
    auto &discarding = standardError ? m_discardStderr : m_discardStdout;
    buffer += standardError ? m_process.readAllStandardError() : m_process.readAllStandardOutput();
    qsizetype newline;
    while ((newline = buffer.indexOf('\n')) >= 0) {
        const auto bytes = buffer.left(newline);
        buffer.remove(0, newline + 1);
        if (!discarding && bytes.size() <= maxLineBytes) line(bytes, standardError);
        else if (!discarding) appendLog("[编辑器] 已忽略过长的输出行。");
        discarding = false;
    }
    if (buffer.size() > maxLineBytes) {
        if (buffer.startsWith(resultPrefix)) m_protocolError = "构建结果超过接收上限。";
        appendLog("[编辑器] 已截断过长的输出行。");
        buffer.clear();
        discarding = true;
    }
    if (flush && !buffer.isEmpty()) {
        if (!discarding) line(buffer, standardError);
        buffer.clear();
    }
    emit changed();
}
void BuildManager::line(const QByteArray &raw, bool standardError) {
    const auto bytes = raw.endsWith('\r') ? raw.chopped(1) : raw;
    if (!standardError && bytes.startsWith(resultPrefix)) {
        if (m_receivedResult) { m_protocolError = "构建器返回了多份构建结果。"; return; }
        m_receivedResult = true;
        const auto document = QJsonDocument::fromJson(bytes.mid(qstrlen(resultPrefix)));
        if (!document.isObject() || !validProtocol(document.object())) {
            m_protocolError = "无法识别构建结果，要求 xcshop-builder/result 协议版本 0。";
            return;
        }
        const auto object = document.object();
        m_result = object.toVariantMap();
        for (const auto &name : {"errors", "warnings"}) {
            for (const auto &value : object[name].toArray()) {
                auto problem = value.toObject().toVariantMap();
                problem["severity"] = QString(name) == "errors" ? "error" : "warning";
                problem["message"] = problem["reason"];
                m_problems << problem;
            }
        }
        return; // Keep the machine result out of the human-readable console.
    }
    appendLog((standardError ? "[stderr] " : "") + QString::fromUtf8(bytes));
}
void BuildManager::finish(int exitCode, QProcess::ExitStatus status) {
    if (!m_running) return;
    readChannel(false, true);
    readChannel(true, true);
    m_elapsed = m_clock.elapsed();
    m_tick.stop();
    m_killTimer.stop();
    bool success = false;
    if (m_cancelled) {
        m_state = "已取消";
        m_summary = m_process.arguments().contains("--check") ? "检查已停止" : "构建已停止，请重新构建后再使用输出";
    } else if (status == QProcess::CrashExit) {
        integrationError("构建器异常退出。", "请查看控制台输出，并检查构建器运行库或内部异常。");
    } else if (!m_protocolError.isEmpty() || !m_receivedResult || m_result.isEmpty()) {
        integrationError(m_protocolError.isEmpty() ? "构建器未返回完整的结果。" : m_protocolError,
                         "请使用支持结果协议版本 0 的构建器；控制台中的普通输出不会被当作构建结果。");
    } else if (!m_result["internalError"].toString().isEmpty()) {
        integrationError("构建器内部错误：" + m_result["internalError"].toString(), "请保留构建日志以排查程序问题。");
    } else {
        success = exitCode == 0 && m_result["buildSucceeded"].toBool()
                && m_result["buildEndedNormally"].toBool() && !m_result["terminatedEarly"].toBool()
                && m_result["errorCount"].toInt() == 0;
        const bool checkOnly = m_result["mode"].toString() == "check";
        const bool outputWritten = !checkOnly && m_result["outputWritten"].toBool();
        if (checkOnly || !outputWritten) m_outputPath.clear();
        m_state = checkOnly ? (success ? "检查通过" : "检查失败") : (success ? "构建成功" : "构建失败");
        m_summary = success ? (outputWritten ? "数据包已生成" : "未生成数据包")
                           : checkOnly ? "请修正问题后重新检查" : "构建已终止，请修正问题后重试";
        if (!success && m_problems.isEmpty())
            integrationError("构建未成功，但构建器没有提供错误详情（退出码 " + QString::number(exitCode) + "）。",
                             "请检查控制台输出及构建器返回的结果。");
    }
    appendLog("[编辑器] " + m_state + "（退出码 " + QString::number(exitCode) + "）");
    setRunning(false);
    emit changed();
    emit completed(success);
}
