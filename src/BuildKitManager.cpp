#include "BuildKitManager.h"
#include "MinecraftDataPackVersions.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDirIterator>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QSettings>
#include <QUrl>
#include <algorithm>
#include <QHash>
#include <QFileInfo>
#include <array>
#include <optional>
#include <limits>
#include <QTemporaryDir>
#include <QtConcurrent/QtConcurrentRun>
#include <stdexcept>

namespace {
const QRegularExpression uuidPattern(QStringLiteral("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"));

QString readText(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    auto bytes = file.readAll();
    if (bytes.startsWith("\xef\xbb\xbf")) bytes.remove(0, 3);
    return QString::fromUtf8(bytes).replace("\r\n", "\n").replace('\r', '\n');
}

// Matches the builder's ordering, including the 1.21.11 -> 26.1 transition.
std::optional<std::array<int, 5>> versionKey(const QString &version) {
    static const QRegularExpression pattern(QStringLiteral("^(1|[2-9][0-9])\\.([0-9]+)(?:\\.([0-9]+))?(?:-(pre|rc|snapshot)-?([0-9]+))?$"));
    const auto match = pattern.match(version);
    if (!match.hasMatch()) return {};
    std::array<int, 5> key{0, 0, 0, 3, 0};
    for (int i = 0; i < 3; ++i) {
        const auto text = match.captured(i + 1);
        if (text.isEmpty()) continue;
        bool ok = false;
        key[i] = text.toInt(&ok);
        if (!ok || (text.size() > 1 && text.startsWith('0'))) return {};
    }
    if (key[0] == 1) {
        if (key[1] > 21 || (key[1] == 21 && key[2] > 11)) return {};
    } else if (key[0] < 26 || key[1] < 1) return {};
    if (!match.captured(4).isEmpty()) {
        key[3] = match.captured(4) == "snapshot" ? 0 : match.captured(4) == "pre" ? 1 : 2;
        bool ok = false;
        key[4] = match.captured(5).toInt(&ok);
        if (!ok || key[4] < 1) return {};
    }
    return key;
}

bool within(const QString &root, const QString &path) {
    const QString relative = QDir(root).relativeFilePath(path);
    return relative != ".." && !relative.startsWith("../") && !QDir::isAbsolutePath(relative);
}

QString dependency(const QString &root, const QString &base, const QString &relative) {
    if (relative.isEmpty() || QDir::isAbsolutePath(relative) || relative.contains(':')) return {};
    const QFileInfo info(QDir(base).filePath(relative));
    const QString path = info.canonicalFilePath();
    return !path.isEmpty() && within(root, path) ? path : QString();
}

QVariantMap parseTemplate(const QString &root, const QString &path) {
    const auto text = readText(path);
    const auto lines = text.split('\n');
    QVariantMap result{{"id", lines.value(0).trimmed().toLower()},
                       {"name", QFileInfo(path).completeBaseName()}, {"path", path},
                       {"relativePath", QDir(root).relativeFilePath(path)},
                       {"valid", false}, {"dataVersion", -1}, {"allowsNewer", false}};
    QStringList errors;
    if (!uuidPattern.match(lines.value(0).trimmed()).hasMatch()) errors << "第一行必须是标准 UUID。";
    bool numberOk = false;
    const auto schema = lines.value(1).trimmed();
    const auto number = schema.toLongLong(&numberOk);
    if (!QRegularExpression("^[0-9]+$").match(schema).hasMatch() || !numberOk || number > std::numeric_limits<int>::max())
        errors << "第二行必须是非负整数数据版本。";
    else result["dataVersion"] = int(number);
    QString versionText = lines.value(2).trimmed();
    const bool newer = versionText.endsWith("...");
    if (newer) {
        versionText.chop(3);
        versionText = versionText.trimmed();
        if (versionText.endsWith(',')) versionText.chop(1);
    }
    QJsonParseError jsonError;
    const auto versions = QJsonDocument::fromJson(("[" + versionText + "]").toUtf8(), &jsonError);
    QStringList values;
    bool versionsOk = jsonError.error == QJsonParseError::NoError && versions.isArray() && !versions.array().isEmpty();
    for (const auto &value : versions.array()) {
        if (!value.isString() || value.toString().trimmed().isEmpty() || value.toString() == "..." || values.contains(value.toString())) {
            versionsOk = false;
            continue;
        }
        const auto previous = values.isEmpty() ? std::nullopt : versionKey(values.last());
        const auto current = versionKey(value.toString());
        if (previous && current && *previous >= *current) versionsOk = false;
        values << value.toString();
    }
    if (!versionsOk) errors << "第三行必须是从旧到新、不重复的版本字符串列表，可在末尾加 ...。";
    result["versions"] = values;
    result["allowsNewer"] = newer;
    const auto blueprint = dependency(root, QFileInfo(path).absolutePath(), lines.value(3).trimmed());
    const auto materials = dependency(root, QFileInfo(path).absolutePath(), lines.value(4).trimmed());
    if (!QFileInfo(blueprint).isFile() || !blueprint.endsWith(".xcshoper")) errors << "第四行引用的蓝图不存在、越出套件目录，或不是 .xcshoper。";
    if (!QFileInfo(materials).isDir()) errors << "第五行引用的材料包目录不存在或越出套件目录。";
    int materialCount = 0;
    if (!materials.isEmpty()) {
        for (const auto &entry : QDir(materials).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden)) {
            if (!entry.isFile()) errors << "材料包内不能包含二级目录或非普通文件。";
            if (entry.suffix() == "xcontent" || entry.suffix() == "xclist") ++materialCount;
        }
    }
    result["blueprintPath"] = blueprint;
    result["materialsPath"] = materials;
    result["materialCount"] = materialCount;
    // Find the closing bracket outside JSON strings. Script text after it is never parsed/executed here.
    const QString intro = lines.mid(5).join('\n');
    qsizetype start = 0, end = -1;
    while (start < intro.size() && (intro[start] == ' ' || intro[start] == '\t')) ++start;
    bool quoted = false, escaped = false;
    int depth = 0;
    if (start < intro.size() && intro[start] == '[') {
        for (qsizetype i = start; i < intro.size(); ++i) {
            const auto c = intro[i];
            if (quoted) {
                if (escaped) escaped = false;
                else if (c == '\\') escaped = true;
                else if (c == '"') quoted = false;
            } else if (c == '"') quoted = true;
            else if (c == '[') ++depth;
            else if (c == ']' && --depth == 0) { end = i + 1; break; }
        }
    }
    QStringList paragraphs;
    const auto document = QJsonDocument::fromJson(end > start ? intro.mid(start, end - start).toUtf8() : QByteArray(), &jsonError);
    bool introOk = jsonError.error == QJsonParseError::NoError && document.isArray();
    for (const auto &value : document.array()) {
        if (!value.isString()) introOk = false;
        else paragraphs << value.toString();
    }
    if (end >= 0) {
        const auto newline = intro.indexOf('\n', end);
        if (!intro.mid(end, newline < 0 ? -1 : newline - end).trimmed().isEmpty()) introOk = false;
    }
    if (!introOk) errors << "第六行须以 JSON 字符串介绍数组开始，检查代码应在 ] 结束后的下一行。";
    result["introduction"] = paragraphs;
    result["error"] = errors.join('\n');
    result["valid"] = errors.isEmpty();
    return result;
}

QByteArray fileHash(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    QCryptographicHash hash(QCryptographicHash::Sha256);
    return hash.addData(&file) ? hash.result() : QByteArray();
}

struct TemplateVersionUpdate {
    QString path;
    QByteArray before, after;
};

std::optional<TemplateVersionUpdate> templateVersionUpdate(const QString &source, const QString &target) {
    QFile incoming(source), existing(target);
    if (!incoming.open(QIODevice::ReadOnly) || !existing.open(QIODevice::ReadOnly)) return {};
    const auto before = existing.readAll();
    const auto normalize = [](QByteArray bytes) {
        if (bytes.startsWith("\xef\xbb\xbf")) bytes.remove(0, 3);
        return bytes.replace("\r\n", "\n").replace('\r', '\n');
    };
    auto incomingLines = normalize(incoming.readAll()).split('\n');
    const auto existingLines = normalize(before).split('\n');
    if (incomingLines.size() < 3 || existingLines.size() < 3) return {};
    const auto versions = incomingLines[2];
    incomingLines[2] = existingLines[2];
    if (incomingLines != existingLines) return {};
    // Locate the third line in the original bytes to retain the local BOM and line endings.
    qsizetype start = 0;
    for (int line = 0; line < 2; ++line) {
        while (start < before.size() && before[start] != '\r' && before[start] != '\n') ++start;
        if (start < before.size() && before[start++] == '\r' && start < before.size() && before[start] == '\n') ++start;
    }
    auto end = start;
    while (end < before.size() && before[end] != '\r' && before[end] != '\n') ++end;
    auto after = before;
    after.replace(start, end - start, versions);
    return TemplateVersionUpdate{target, before, after};
}

bool replaceFile(const QString &path, const QByteArray &bytes) {
    QSaveFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size() && file.commit();
}
}

BuildKitManager::BuildKitManager(QObject *parent)
    : BuildKitManager(QUrl("https://xczongzi.net/projects/xcshop/downloads/kits.zip"), parent) {}
BuildKitManager::BuildKitManager(const QUrl &downloadUrl, QObject *parent)
    : BuildKitManager(downloadUrl, QCoreApplication::applicationDirPath() + "/kits-download-state.ini",
                      60000, parent) {}
BuildKitManager::BuildKitManager(const QUrl &downloadUrl, const QString &downloadStatePath,
                                 int downloadCooldownMs, QObject *parent)
    : QObject(parent), m_kitsPath(defaultKitsPath()), m_downloadUrl(downloadUrl),
      m_downloadStatePath(downloadStatePath), m_downloadCooldownMs(qMax(1, downloadCooldownMs)) {
    // Persist across restarts, then use a monotonic deadline while running.
    // Bound the restored wait if the system clock was moved backwards.
    QSettings state(m_downloadStatePath, QSettings::IniFormat);
    const auto lastAttempt = state.value("downloads/lastAttemptMs", 0).toLongLong();
    if (lastAttempt > 0) {
        const auto elapsed = qMax(qint64(0), QDateTime::currentMSecsSinceEpoch() - lastAttempt);
        m_downloadCooldown = QDeadlineTimer(qMax(qint64(0), m_downloadCooldownMs - elapsed));
    }
    m_downloadCooldownTimer.setInterval(250);
    connect(&m_downloadCooldownTimer, &QTimer::timeout, this, &BuildKitManager::updateDownloadCooldown);
    updateDownloadCooldown();
    connect(&m_acquisitionWatcher, &QFutureWatcher<QString>::finished, this, [this] {
        const auto error = m_acquisitionWatcher.result();
        m_acquiring = false;
        m_cancel.reset();
        m_acquisitionProgress = error.isEmpty() ? 100 : 0;
        m_acquisitionStatus = error.isEmpty() ? "套件已导入，相同内容的已有文件已复用。" : error;
        refresh();
        emit acquisitionChanged();
        emit busyChanged();
        emit acquisitionFinished(error.isEmpty(), m_acquisitionStatus);
    });
    refresh();
}
BuildKitManager::~BuildKitManager() {
    cancelAcquisition();
    m_acquisitionWatcher.waitForFinished();
}
QString BuildKitManager::defaultKitsPath() const { return QCoreApplication::applicationDirPath() + "/kits"; }
QVariantMap BuildKitManager::resolveDataPackVersion(const QString &version) const {
    return MinecraftDataPackVersions::resolve(
        QDir(QCoreApplication::applicationDirPath()).filePath("minecraft-data-pack-versions.json"), version);
}

QString BuildKitManager::localPath(const QString &path) const {
    const QUrl url(path);
    const auto value = url.isLocalFile() ? url.toLocalFile() : path.trimmed();
    return value.isEmpty() ? QString() : QDir::cleanPath(QFileInfo(value).absoluteFilePath());
}
void BuildKitManager::setKitsPath(const QString &path) {
    if (busy()) return;
    const auto next = localPath(path);
    if (next == m_kitsPath) return;
    m_kitsPath = next;
    emit kitsPathChanged();
    refresh();
}
void BuildKitManager::setPreferredTemplateId(const QString &id) {
    const auto value = id.trimmed().toLower();
    if (value == m_preferredTemplateId) return;
    m_preferredTemplateId = value;
    emit preferredTemplateIdChanged();
}
void BuildKitManager::setBusy(bool value) {
    if (m_busy == value) return;
    m_busy = value;
    emit busyChanged();
}
void BuildKitManager::refresh() {
    m_templates.clear();
    m_issues.clear();
    const auto root = QFileInfo(m_kitsPath).canonicalFilePath();
    const auto templateRoot = QDir(root).filePath("templates");
    m_identityValid = !root.isEmpty() && QFileInfo(templateRoot).isDir() && within(root, QFileInfo(templateRoot).canonicalFilePath());
    if (!m_identityValid) m_issues << "找不到有效的 kits/templates 目录，请选择构建套件根目录。";
    else {
        QHash<QString, int> identities;
        QDirIterator files(templateRoot, QDir::AllEntries | QDir::Hidden | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (files.hasNext()) {
            const auto path = files.next();
            if (files.fileInfo().isSymLink()) {
                m_identityValid = false;
                m_issues << path + "：模板目录不能包含符号链接。";
                continue;
            }
            if (!files.fileInfo().isFile() || !path.endsWith(".xcshopT")) continue;
            auto item = parseTemplate(root, path);
            const auto id = item["id"].toString();
            if (!uuidPattern.match(id).hasMatch()) m_identityValid = false;
            if (identities.contains(id)) {
                m_identityValid = false;
                const int previous = identities.value(id);
                auto duplicate = m_templates[previous].toMap();
                duplicate["valid"] = false;
                duplicate["error"] = duplicate["error"].toString() + "\n模板 ID 重复：" + path;
                m_templates[previous] = duplicate;
                item["valid"] = false;
                item["error"] = item["error"].toString() + "\n模板 ID 重复：" + duplicate["path"].toString();
            } else identities.insert(id, int(m_templates.size()));
            m_templates << item;
        }
        std::sort(m_templates.begin(), m_templates.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap()["relativePath"].toString() < b.toMap()["relativePath"].toString();
        });
        for (const auto &value : m_templates) {
            const auto item = value.toMap();
            if (!item["valid"].toBool()) m_issues << item["relativePath"].toString() + "：" + item["error"].toString();
        }
    }
    emit catalogChanged();
}
QVariantMap BuildKitManager::findTemplate(const QString &id) const {
    for (const auto &value : m_templates)
        if (value.toMap()["id"].toString() == id.toLower()) return value.toMap();
    return {};
}
QVariantList BuildKitManager::options(int requiredDataVersion) const {
    QVariantList result;
    if (!m_identityValid) return result;
    for (const auto &value : m_templates) {
        auto item = value.toMap();
        if (!item["valid"].toBool() || item["dataVersion"].toInt() != requiredDataVersion) continue;
        item["value"] = item["id"];
        item["label"] = item["name"];
        result << item;
    }
    return result;
}
int BuildKitManager::versionSupport(const QString &id, const QString &version) const {
    const auto item = findTemplate(id);
    if (!item["valid"].toBool()) return -1;
    const auto versions = item["versions"].toStringList();
    if (versions.contains(version)) return 0;
    const auto current = versionKey(version);
    const auto last = versions.isEmpty() ? std::nullopt : versionKey(versions.last());
    return item["allowsNewer"].toBool() && current && last && *current > *last ? 1 : -1;
}

QString BuildKitManager::importKit(const QString &sourceRoot) {
    if (busy()) return "构建或获取套件期间不能更改套件。";
    return importDirectory(sourceRoot);
}

void BuildKitManager::updateDownloadCooldown() {
    const int seconds = int((m_downloadCooldown.remainingTime() + 999) / 1000);
    if (seconds != m_downloadCooldownSeconds) {
        m_downloadCooldownSeconds = seconds;
        emit downloadCooldownChanged();
    }
    if (seconds > 0) m_downloadCooldownTimer.start();
    else m_downloadCooldownTimer.stop();
}

void BuildKitManager::acquire(const QString &source) {
    if (busy()) return;
    if (source.isEmpty()) {
        updateDownloadCooldown();
        if (m_downloadCooldownSeconds > 0) {
            m_acquisitionStatus = QString("下载过于频繁，请在 %1 秒后重试。").arg(m_downloadCooldownSeconds);
            emit acquisitionChanged();
            emit acquisitionFinished(false, m_acquisitionStatus);
            return;
        }
        // Start at the attempt, so failures and cancellations also respect the limit.
        m_downloadCooldown = QDeadlineTimer(m_downloadCooldownMs);
        QSettings state(m_downloadStatePath, QSettings::IniFormat);
        state.setValue("downloads/lastAttemptMs", QDateTime::currentMSecsSinceEpoch());
        state.sync();
        if (state.status() != QSettings::NoError)
            qWarning("Could not save kit download cooldown to kits-download-state.ini");
        updateDownloadCooldown();
    }
    m_acquiring = true;
    m_acquisitionProgress = -1;
    m_acquisitionStatus = "正在准备套件…";
    m_cancel = std::make_shared<std::atomic_bool>(false);
    emit busyChanged();
    emit acquisitionChanged();
    const auto target = m_kitsPath;
    const auto path = source.isEmpty() ? QString() : localPath(source);
    const auto url = m_downloadUrl;
    const auto cancel = m_cancel;
    m_acquisitionWatcher.setFuture(QtConcurrent::run([this, path, target, url, cancel] {
        try {
            QTemporaryDir staging;
            if (!staging.isValid()) return QString("无法创建套件临时目录。");
            const auto progress = [this](int value, const QString &status) {
                QMetaObject::invokeMethod(this, [this, value, status] {
                    m_acquisitionProgress = value;
                    m_acquisitionStatus = status;
                    emit acquisitionChanged();
                }, Qt::QueuedConnection);
            };
            const auto root = BuildKitArchive::prepare(path, url, staging.path(), cancel, progress);
            progress(90, "正在校验并导入套件…");
            BuildKitManager worker;
            worker.setKitsPath(target);
            return worker.importDirectory(root, cancel, path.isEmpty());
        } catch (const std::exception &error) {
            return QString::fromUtf8(error.what());
        }
    }));
}
void BuildKitManager::cancelAcquisition() {
    if (m_cancel) m_cancel->store(true);
}

QString BuildKitManager::importDirectory(const QString &sourceRoot, const BuildKitArchive::Cancellation &cancel,
                                        bool updateTemplateVersions) {
    const auto cancelled = [&] { return cancel && cancel->load(); };
    if (cancelled()) return "已取消获取套件。";
    const auto source = QFileInfo(localPath(sourceRoot)).canonicalFilePath();
    const auto target = localPath(m_kitsPath);
    if (target.isEmpty()) return "请先设置有效的套件目录。";
    // Resolve existing ancestors as well: a not-yet-created kit root must not
    // silently write through a link/junction in its parent path.
    for (auto ancestor = QFileInfo(target); ; ancestor = QFileInfo(ancestor.absolutePath())) {
        if (ancestor.isSymLink() || ancestor.isJunction()) return "目标路径包含符号链接：" + ancestor.filePath();
        if (ancestor.absoluteFilePath() == ancestor.absolutePath()) break;
    }
    if (source.isEmpty() || source == target || within(source, target) || within(target, source))
        return "请选择与当前套件目录相互独立的构建套件根目录。";
    BuildKitManager incoming;
    incoming.setKitsPath(source);
    if (!incoming.identityValid() || incoming.templates().isEmpty() || !incoming.issues().isEmpty())
        return "待导入的套件无效：\n" + incoming.issues().join('\n');
    refresh();
    if (!m_templates.isEmpty() && !m_identityValid) return "当前套件目录的模板 ID 无效或重复，请先修复后再导入。";
    QSet<QString> versionUpdatePaths;
    for (const auto &value : incoming.templates()) {
        const auto item = value.toMap();
        const auto existing = findTemplate(item["id"].toString());
        if (!existing.isEmpty() && existing["relativePath"] != item["relativePath"])
            return "模板 ID 已存在，不能以另一个文件名重复导入：" + item["name"].toString();
        if (updateTemplateVersions && !existing.isEmpty())
            versionUpdatePaths.insert(item["relativePath"].toString());
    }
    // Validate the complete merge before writing; online templates may differ only on line three.
    QStringList additions, directories;
    QList<TemplateVersionUpdate> versionUpdates;
    QDirIterator files(source, QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden, QDirIterator::Subdirectories);
    while (files.hasNext()) {
        if (cancelled()) return "已取消获取套件。";
        const auto path = files.next();
        const auto info = files.fileInfo();
        if (info.isSymLink() || info.isJunction()) return "不能导入包含符号链接的套件：" + path;
        const auto relative = QDir(source).relativeFilePath(path);
        const auto destination = QDir(target).filePath(relative);
        const auto existing = QFileInfo(destination);
        if (existing.isSymLink() || existing.isJunction()) return "目标目录包含符号链接：" + destination;
        if (info.isDir()) {
            if (existing.exists() && !existing.isDir()) return "目录与已有文件冲突：" + destination;
            if (!existing.exists()) directories << destination;
        } else if (info.isFile()) {
            if (existing.exists()) {
                const auto hash = fileHash(path);
                if (!existing.isFile() || hash.isEmpty())
                    return "同名文件内容不同，未覆盖任何文件：" + destination;
                if (hash != fileHash(destination)) {
                    const auto update = versionUpdatePaths.contains(relative)
                        ? templateVersionUpdate(path, destination) : std::nullopt;
                    if (!update) return "同名文件内容不同，未覆盖任何文件：" + destination;
                    if (update->before != update->after) versionUpdates << *update;
                }
            } else additions << relative;
        } else return "套件包含非普通文件：" + path;
    }
    std::sort(directories.begin(), directories.end(), [](const auto &a, const auto &b) { return a.size() < b.size(); });
    std::sort(versionUpdates.begin(), versionUpdates.end(), [](const auto &a, const auto &b) { return a.path < b.path; });
    QStringList copied, created;
    QList<TemplateVersionUpdate> updated;
    auto rollback = [&](QString error) {
        QStringList unrestored;
        for (auto it = updated.crbegin(); it != updated.crend(); ++it)
            if (!replaceFile(it->path, it->before)) unrestored << it->path;
        for (const auto &file : copied) QFile::remove(file);
        for (auto it = created.crbegin(); it != created.crend(); ++it) QDir().rmdir(*it);
        if (!unrestored.isEmpty()) error += "\n无法恢复以下模板的版本声明：\n" + unrestored.join('\n');
        return error;
    };
    if (!QFileInfo::exists(target)) {
        if (!QDir().mkpath(target)) return "无法创建套件目录。";
        created << target;
    }
    for (const auto &directory : directories) {
        if (cancelled()) return rollback("已取消获取套件。");
        if (!QDir().mkdir(directory)) return rollback("无法创建目录：" + directory);
        created << directory;
    }
    for (const auto &relative : additions) {
        if (cancelled()) return rollback("已取消获取套件。");
        const auto destination = QDir(target).filePath(relative);
        if (!QFile::copy(QDir(source).filePath(relative), destination)) {
            return rollback("导入失败，已撤销本次新增文件：" + destination);
        }
        copied << destination;
    }
    for (const auto &update : versionUpdates) {
        if (cancelled()) return rollback("已取消获取套件。");
        QFile current(update.path);
        if (!current.open(QIODevice::ReadOnly) || current.readAll() != update.before)
            return rollback("模板在导入期间发生变化，已取消版本更新：" + update.path);
        current.close();
        if (!replaceFile(update.path, update.after))
            return rollback("无法更新模板的版本声明：" + update.path);
        updated << update;
    }
    if (cancelled()) return rollback("已取消获取套件。");
    refresh();
    return {};
}
QString BuildKitManager::removeTemplate(const QString &id) {
    if (busy()) return "构建或获取套件期间不能移除模板。";
    refresh();
    const auto item = findTemplate(id);
    if (item.isEmpty()) return "找不到该模板。";
    if (!QFile::moveToTrash(item["path"].toString())) return "无法移入回收站，模板未被移除。";
    if (m_preferredTemplateId == id.toLower()) setPreferredTemplateId({});
    refresh();
    return {};
}
