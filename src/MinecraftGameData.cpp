#include "MinecraftImportSupport.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonDocument>
#include <QLockFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QSysInfo>
#include <QTemporaryDir>
#include <QTimer>
#include <QThread>
#include <QUrl>
#include <QUuid>
#include <algorithm>
#include <limits>
#include <stdexcept>

namespace MinecraftImport {
namespace {
const QString manifestUrl = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";

void require(bool condition, const QString &message)
{
    if (!condition) throw std::runtime_error(message.toUtf8().constData());
}

void checkpoint(const Cancellation &cancel)
{
    require(!cancel || !cancel->load(), "已取消导入，当前资源未被修改。");
}

QByteArray readBytes(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray{};
}

QJsonObject readObject(const QString &path)
{
    return QJsonDocument::fromJson(readBytes(path)).object();
}

void writeJson(const QString &path, const QJsonObject &object)
{
    require(QDir().mkpath(QFileInfo(path).absolutePath()), "无法创建缓存目录。");
    QSaveFile file(path);
    require(file.open(QIODevice::WriteOnly), "无法写入：" + path);
    const auto bytes = QJsonDocument(object).toJson(QJsonDocument::Compact);
    require(file.write(bytes) == bytes.size() && file.commit(), "无法保存：" + path);
}

QString sha1(const QString &path, const Cancellation &cancel)
{
    QFile file(path);
    require(file.open(QIODevice::ReadOnly), "无法读取文件：" + path);
    QCryptographicHash hash(QCryptographicHash::Sha1);
    while (!file.atEnd()) {
        checkpoint(cancel);
        hash.addData(file.read(1024 * 1024));
    }
    return QString::fromLatin1(hash.result().toHex());
}

bool officialUrl(const QUrl &url)
{
    const QString host = url.host().toLower();
    return url.scheme() == "https" && (host == "mojang.com" || host.endsWith(".mojang.com")
           || host == "minecraft.net" || host.endsWith(".minecraft.net"));
}

// All network work lives on its worker thread. Downloads are streamed to a
// QSaveFile, verified before use, and interrupted promptly when cancelled.
QByteArray download(const QUrl &url, const QString &destination, const QString &expectedHash,
                    const Cancellation &cancel, const Progress &progress = {}, int step = 0)
{
    checkpoint(cancel);
    require(officialUrl(url), "版本元数据包含非官方或非 HTTPS 下载地址。");
    QNetworkAccessManager network;
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "xcshop/MinecraftImporter");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::SameOriginRedirectPolicy);
    request.setTransferTimeout(60000);
    auto *reply = network.get(request);
    QEventLoop loop;
    QTimer tick;
    tick.setInterval(100);
    QObject::connect(&tick, &QTimer::timeout, &loop, [&] {
        if (cancel && cancel->load()) reply->abort();
    });
    QSaveFile file(destination);
    if (!destination.isEmpty()) {
        require(QDir().mkpath(QFileInfo(destination).absolutePath()) && file.open(QIODevice::WriteOnly),
                "无法创建下载缓存。");
    }
    QByteArray bytes;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    bool writeFailed = false;
    const auto consume = [&] {
        const auto chunk = reply->readAll();
        hash.addData(chunk);
        if (destination.isEmpty()) {
            bytes += chunk;
            if (bytes.size() > 32 * 1024 * 1024) { writeFailed = true; reply->abort(); }
        } else if (file.write(chunk) != chunk.size()) { writeFailed = true; reply->abort(); }
    };
    QObject::connect(reply, &QIODevice::readyRead, &loop, consume);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QElapsedTimer throttle;
    throttle.start();
    QObject::connect(reply, &QNetworkReply::downloadProgress, &loop, [&](qint64 received, qint64 total) {
        if (progress && throttle.elapsed() > 250) {
            throttle.restart();
            progress(step, QString("正在下载官方游戏文件：%1 / %2 MiB")
                     .arg(received / 1048576.0, 0, 'f', 1)
                     .arg(total > 0 ? QString::number(total / 1048576.0, 'f', 1) : "未知"));
        }
    });
    tick.start();
    loop.exec();
    consume();
    checkpoint(cancel);
    require(!writeFailed, "下载缓存写入失败或元数据过大。");
    require(reply->error() == QNetworkReply::NoError,
            "无法下载官方游戏数据：" + reply->errorString());
    require(expectedHash.isEmpty() || QString::fromLatin1(hash.result().toHex()) == expectedHash,
            "官方文件校验失败，请重试下载。");
    if (!destination.isEmpty()) require(file.commit(), "无法保存下载文件。");
    return bytes;
}

QJsonObject manifest(const QString &cache, const Cancellation &cancel, bool refresh, bool allowNetwork = true)
{
    const auto path = cache + "/manifest.json";
    auto cached = readObject(path);
    if (!refresh && !cached.value("versions").toArray().isEmpty()) return cached;
    require(allowNetwork, "离线缓存中没有官方版本列表。请允许联网补齐，或选择完整的本地游戏安装。");
    try {
        const auto object = QJsonDocument::fromJson(download(QUrl(manifestUrl), {}, {}, cancel)).object();
        require(!object.value("versions").toArray().isEmpty(), "官方版本列表格式无效。");
        writeJson(path, object);
        return object;
    } catch (...) {
        checkpoint(cancel);
        if (cached.value("versions").toArray().isEmpty()) throw;
        cached.insert("xcshopOffline", true);
        return cached;
    }
}

QJsonObject versionMetadata(const QString &cache, const QJsonObject &entry, const Cancellation &cancel,
                            bool allowNetwork = true)
{
    const QString id = entry.value("id").toString();
    require(QRegularExpression("^[A-Za-z0-9_.+-]+$").match(id).hasMatch(), "无效的游戏版本标识。");
    const QString path = cache + "/versions/" + id + ".json";
    const QString expected = entry.value("sha1").toString();
    require(QRegularExpression("^[a-f0-9]{40}$").match(expected).hasMatch(), "官方版本元数据缺少有效校验值。");
    if (QFileInfo::exists(path) && !expected.isEmpty() && sha1(path, cancel) == expected) {
        const auto object = readObject(path);
        if (object.value("id").toString() == id) return object;
    }
    require(allowNetwork, "缺少 Minecraft " + id + " 的版本信息。请提供同目录的版本 JSON，或允许联网补齐。");
    download(QUrl(entry.value("url").toString()), path, expected, cancel);
    const auto object = readObject(path);
    require(object.value("id").toString() == id && !object.value("downloads").toObject().isEmpty(),
            "官方版本元数据无效。");
    return object;
}

QString gameFile(const QString &cache, const QJsonObject &entry, const Cancellation &cancel,
                 const Progress &progress, int step, bool allowNetwork = true)
{
    const QString hash = entry.value("sha1").toString();
    require(QRegularExpression("^[a-f0-9]{40}$").match(hash).hasMatch(), "官方文件缺少有效校验值。");
    const QString path = cache + "/downloads/" + hash + ".jar";
    if (!QFileInfo::exists(path) || sha1(path, cancel) != hash) {
        require(allowNetwork, "本地缓存中缺少所需游戏 JAR。请允许联网补齐，或选择本地客户端。");
        download(QUrl(entry.value("url").toString()), path, hash, cancel, progress, step);
    }
    return path;
}

struct ProcessResult { int code; QByteArray output; };
ProcessResult run(const QString &program, const QStringList &arguments, const QString &directory,
                  int timeout, const Cancellation &cancel, const Progress &progress = {}, int step = 0)
{
    checkpoint(cancel);
    QProcess process;
    process.setWorkingDirectory(directory);
    process.setProcessChannelMode(QProcess::MergedChannels);
    process.start(program, arguments);
    require(process.waitForStarted(5000), "无法启动 " + program + "：" + process.errorString());
    QElapsedTimer clock;
    clock.start();
    QByteArray output;
    qint64 lastNotice = 0;
    while (!process.waitForFinished(100)) {
        output += process.readAll();
        if (output.size() > 512 * 1024) output = output.right(256 * 1024);
        if ((cancel && cancel->load()) || clock.elapsed() > timeout) {
            process.kill();
            process.waitForFinished(3000);
            checkpoint(cancel);
            throw std::runtime_error("游戏数据生成超时，请检查 Java 与该版本是否兼容。");
        }
        if (progress && clock.elapsed() - lastNotice > 1000) {
            lastNotice = clock.elapsed();
            progress(step, QString("正在运行游戏数据生成器… %1 秒").arg(clock.elapsed() / 1000));
        }
    }
    output += process.readAll();
    return {process.exitStatus() == QProcess::NormalExit ? process.exitCode() : -1, output};
}

QString tarExecutable()
{
    const auto path = QStandardPaths::findExecutable("tar");
    require(!path.isEmpty(), "未找到 tar 解压工具，请安装系统归档工具后重试。");
    return path;
}

QJsonObject embeddedVersion(const QString &jar, const Cancellation &cancel)
{
    const auto embedded = run(tarExecutable(), {"-xOf", jar, "version.json"},
                              QFileInfo(jar).absolutePath(), 30000, cancel);
    return QJsonDocument::fromJson(embedded.output).object();
}

bool validVersionId(const QString &id)
{
    return id != "." && id != ".." && QRegularExpression("^[A-Za-z0-9_.+-]+$").match(id).hasMatch();
}

QStringList installationRoots(const QString &location)
{
    QStringList result;
    const auto path = localPath(location);
    QDir directory(QFileInfo(path).isDir() ? path : QFileInfo(path).absolutePath());
    // Launchers often share libraries and Java above a version/instance folder.
    for (int i = 0; i < 10; ++i) {
        result << directory.absolutePath();
        if (!directory.cdUp()) break;
    }
    result << qEnvironmentVariable("APPDATA") + "/.minecraft"
           << QDir::homePath() + "/.minecraft"
           << qEnvironmentVariable("APPDATA") + "/PrismLauncher";
    result.removeDuplicates();
    return result;
}

struct LocalInstallation {
    QString jar;
    QString version;
    QJsonObject metadata;
    QJsonObject embedded;
    int count = 1;
    QString profile;
};

QJsonObject adjacentMetadata(const QString &jar)
{
    const QFileInfo file(jar);
    return readObject(file.absolutePath() + "/" + file.completeBaseName() + ".json");
}

bool vanillaMetadata(const QJsonObject &metadata)
{
    const auto main = metadata.value("mainClass").toString();
    return !metadata.contains("inheritsFrom")
        && (main.isEmpty() || main == "net.minecraft.client.main.Main");
}

bool supportedMetadata(const QJsonObject &metadata, const QJsonObject &embedded, const QString &id)
{
    if (embedded.contains("world_version")) return embedded.value("world_version").toInt() >= 1519;
    const auto date = QDateTime::fromString(metadata.value("releaseTime").toString(), Qt::ISODate);
    if (date.isValid()) return date.date() >= QDate(2018, 7, 18);
    const auto parts = id.split('.');
    bool numeric = false;
    const int first = parts.value(0).toInt(&numeric);
    return numeric && ((first == 1 && parts.value(1).toInt() >= 13) || first >= 26);
}

QJsonObject baseGameMetadata(QJsonObject metadata, const QJsonObject &embedded, const QString &version)
{
    // A launcher profile may start Fabric/Forge while its client JAR is still the
    // original game. Run only the game's data entry point and ordinary libraries.
    if (!vanillaMetadata(metadata) || metadata.value("id").toString() != version) {
        QJsonArray libraries;
        for (const auto &value : metadata.value("libraries").toArray()) {
            const auto artifact = value.toObject().value("downloads").toObject().value("artifact").toObject();
            if (officialUrl(QUrl(artifact.value("url").toString()))) libraries.append(value);
        }
        metadata.insert("libraries", libraries);
        metadata.insert("mainClass", "net.minecraft.client.main.Main");
        metadata.remove("inheritsFrom");
        metadata.remove("jar");
        metadata.insert("id", version);
    }
    if (embedded.value("java_version").toInt() > 0)
        metadata.insert("javaVersion", QJsonObject{{"majorVersion", embedded.value("java_version")}});
    return metadata;
}

QStringList inheritedClients(const QString &profilePath, const Cancellation &cancel, QSet<QString> &visited)
{
    const auto absolute = QFileInfo(profilePath).absoluteFilePath();
    if (visited.contains(absolute) || visited.size() >= 32) return {};
    visited.insert(absolute);
    checkpoint(cancel);
    const auto profile = readObject(absolute);
    QStringList references;
    for (const auto &field : {"jar", "inheritsFrom", "clientVersion"}) {
        const auto id = profile.value(field).toString();
        if (!id.isEmpty() && id == id.trimmed() && !id.endsWith('.') && id != "." && id != ".."
            && !QRegularExpression("[/\\\\:\\x00-\\x1f]").match(id).hasMatch()) references << id;
    }
    for (const auto &value : profile.value("components").toArray()) {
        const auto component = value.toObject();
        if (component.value("uid").toString() == "net.minecraft"
            && validVersionId(component.value("version").toString())) references << component.value("version").toString();
    }
    references.removeDuplicates();
    QStringList result;
    for (const auto &root : installationRoots(absolute)) {
        for (const auto &id : references) {
            for (const auto &folder : {root + "/versions/" + id, root + "/" + id}) {
                const auto jar = folder + "/" + id + ".jar";
                if (QFileInfo(jar).isFile()) result << jar;
                const auto parent = folder + "/" + id + ".json";
                if (QFileInfo(parent).isFile()) result << inheritedClients(parent, cancel, visited);
            }
            // Some launchers keep the game itself in their shared Maven tree.
            const QDir folder(root + "/libraries/com/mojang/minecraft/" + id);
            for (const auto &file : folder.entryInfoList({"*client*.jar", id + ".jar"}, QDir::Files))
                result << file.absoluteFilePath();
        }
    }
    result.removeDuplicates();
    return result;
}

LocalInstallation localInstallation(const QString &location, const Cancellation &cancel)
{
    checkpoint(cancel);
    const auto path = localPath(location.trimmed());
    require(!path.isEmpty() && QFileInfo::exists(path), "请选择存在的客户端 JAR 或游戏目录。");
    QStringList candidates;
    QHash<QString, QString> profiles;
    const auto addProfile = [&](const QString &json) {
        const auto metadata = readObject(json);
        if (metadata.isEmpty()) return;
        QSet<QString> visited;
        for (const auto &jar : inheritedClients(json, cancel, visited)) {
            candidates << jar;
            if (!vanillaMetadata(metadata) || metadata.contains("components"))
                profiles.insert(jar, metadata.value("id").toString(QFileInfo(json).completeBaseName()));
        }
    };
    if (QFileInfo(path).isFile()) {
        require(QFileInfo(path).suffix().compare("jar", Qt::CaseInsensitive) == 0, "请选择 Minecraft 游戏 JAR 文件。");
        candidates << QFileInfo(path).absoluteFilePath();
        const QFileInfo file(path);
        addProfile(file.absolutePath() + "/" + file.completeBaseName() + ".json");
    } else {
        for (const auto &base : {path, path + "/.minecraft", path + "/minecraft"}) {
            QDir directory(base);
            for (const auto &file : directory.entryInfoList({"*.jar"}, QDir::Files))
                candidates << file.absoluteFilePath();
            addProfile(directory.filePath(directory.dirName() + ".json"));
            addProfile(directory.filePath("mmc-pack.json"));
            QDir versions(directory.dirName() == "versions" ? base : base + "/versions");
            for (const auto &version : versions.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
                QDir versionDirectory(versions.filePath(version));
                for (const auto &file : versionDirectory.entryInfoList({"*.jar"}, QDir::Files))
                    candidates << file.absoluteFilePath();
                addProfile(versionDirectory.filePath(version + ".json"));
            }
        }
    }
    candidates.removeDuplicates();
    // Compare game versions, including clients stored in modpack profiles.
    std::sort(candidates.begin(), candidates.end(), [](const QString &a, const QString &b) {
        const auto time = [](const QString &file) {
            const auto date = QDateTime::fromString(adjacentMetadata(file).value("releaseTime").toString(), Qt::ISODate);
            return date.isValid() ? date : QFileInfo(file).lastModified();
        };
        return time(a) > time(b);
    });
    LocalInstallation result;
    QSet<QString> versionsFound;
    for (const auto &candidate : candidates) {
        checkpoint(cancel);
        const auto metadata = adjacentMetadata(candidate);
        const auto fileName = QFileInfo(candidate).completeBaseName().toLower();
        if (QFileInfo(path).isDir() && (fileName == "server" || fileName.startsWith("minecraft_server"))) continue;
        const auto embedded = embeddedVersion(candidate, cancel);
        if (embedded.isEmpty() && !vanillaMetadata(metadata)
            && metadata.value("downloads").toObject().value("client").toObject().isEmpty()) continue;
        const auto fallback = metadata.value("clientVersion").toString(
                    vanillaMetadata(metadata) ? metadata.value("id").toString(QFileInfo(candidate).completeBaseName())
                                              : metadata.value("inheritsFrom").toString());
        const auto id = embedded.value("id").toString(fallback);
        if (!validVersionId(id) || !supportedMetadata(metadata, embedded, id)) continue;
        versionsFound.insert(id);
        if (result.jar.isEmpty()) {
            const auto profile = profiles.value(candidate, !vanillaMetadata(metadata)
                                                ? metadata.value("id").toString(QFileInfo(candidate).completeBaseName()) : "");
            result = {candidate, id, baseGameMetadata(metadata, embedded, id), embedded, 1, profile};
        }
    }
    require(!result.jar.isEmpty(), "未找到 Minecraft 1.13+ 游戏本体。可选择整合包里的游戏 JAR 或版本目录；继承配置需要本地基础版本文件，1.13 请保留版本 JSON。");
    result.count = versionsFound.size();
    return result;
}

QString javaExecutable(QString selected, int required, const Cancellation &cancel, const QStringList &gameRoots = {})
{
    selected = localPath(selected.trimmed());
    if (QFileInfo(selected).isDir()) {
#ifdef Q_OS_WIN
        selected = QDir(selected).filePath("bin/java.exe");
#else
        selected = QDir(selected).filePath("bin/java");
#endif
    }
    QStringList candidates;
    if (!selected.isEmpty()) candidates << selected;
    else {
        const QString javaHome = qEnvironmentVariable("JAVA_HOME");
        if (!javaHome.isEmpty()) candidates << javaHome + "/bin/java";
        candidates << QStandardPaths::findExecutable("java");
        // Discover existing launcher runtimes; do not install or alter system Java.
        QStringList roots{qEnvironmentVariable("ProgramFiles") + "/Java",
                          QDir::homePath() + "/.minecraft/runtime",
                          qEnvironmentVariable("APPDATA") + "/.minecraft/runtime"};
        for (const auto &root : gameRoots)
            for (const auto &name : {"runtime", "java", "jre", "runtimes"})
                roots << root + "/" + name;
        roots.removeDuplicates();
        for (const auto &root : roots) {
            if (!QDir(root).exists()) continue;
            QDirIterator files(root, {"java.exe", "java"}, QDir::Files, QDirIterator::Subdirectories);
            while (files.hasNext()) candidates << files.next();
        }
    }
    candidates.removeAll({});
    candidates.removeDuplicates();
    QString fallback;
    int fallbackVersion = std::numeric_limits<int>::max();
    for (const auto &candidate : candidates) {
        checkpoint(cancel);
        const auto executable = QFileInfo(candidate).isFile() ? candidate : QStandardPaths::findExecutable(candidate);
        if (executable.isEmpty()) continue;
        const auto result = run(executable, {"-version"}, QDir::tempPath(), 10000, cancel);
        const auto match = QRegularExpression("version\\s+\"(?:1\\.)?(\\d+)")
                           .match(QString::fromUtf8(result.output));
        if (!match.hasMatch() || result.code != 0) continue;
        const int major = match.captured(1).toInt();
        if (major == required) return executable;
        if (major >= required && major < fallbackVersion) {
            fallback = executable;
            fallbackVersion = major;
        }
    }
    require(!fallback.isEmpty(), QString("未找到可用的 Java %1 或更高版本，请在设置中选择 Java 可执行文件。").arg(required));
    return fallback;
}

bool safeLibraryPath(const QString &path)
{
    if (!QRegularExpression("^[A-Za-z0-9_.+/-]+$").match(path).hasMatch()) return false;
    for (const auto &part : path.split('/'))
        if (part.isEmpty() || part == "." || part == "..") return false;
    return !QDir::isAbsolutePath(path);
}

bool libraryAllowed(const QJsonObject &library)
{
    if (!library.contains("rules")) return true;
#ifdef Q_OS_WIN
    const QString osName = "windows";
#elif defined(Q_OS_MACOS)
    const QString osName = "osx";
#else
    const QString osName = "linux";
#endif
    QString arch = QSysInfo::currentCpuArchitecture();
    if (arch == "x86_64") arch = "amd64";
    bool allowed = false;
    for (const auto &value : library.value("rules").toArray()) {
        const auto rule = value.toObject();
        const auto os = rule.value("os").toObject();
        if (os.contains("name") && os.value("name").toString() != osName) continue;
        if (os.contains("arch") && !QRegularExpression(os.value("arch").toString()).match(arch).hasMatch()) continue;
        if (os.contains("version") && !QRegularExpression(os.value("version").toString()).match(QSysInfo::kernelVersion()).hasMatch()) continue;
        bool matches = true;
        const auto features = rule.value("features").toObject();
        for (auto it = features.begin(); it != features.end(); ++it)
            if (it.value().toBool()) matches = false; // No optional launcher features for reports.
        if (matches) allowed = rule.value("action").toString() == "allow";
    }
    return allowed;
}

struct PreparedLibraries { QStringList paths; QJsonArray downloads; };

PreparedLibraries clientLibraries(const QString &cache, const QJsonObject &metadata,
                                  const QString &location, const QString &selectedRoot, bool allowNetwork,
                                  const Cancellation &cancel)
{
    require(metadata.value("libraries").isArray() && !metadata.value("libraries").toArray().isEmpty(),
            "版本 JSON 缺少依赖信息。请提供完整的本地版本 JSON，或允许联网读取官方信息。");
    QStringList roots;
    if (!selectedRoot.isEmpty()) roots << localPath(selectedRoot) << localPath(selectedRoot) + "/libraries";
    for (const auto &root : installationRoots(location))
        roots << root + "/libraries" << root + "/.minecraft/libraries";
    roots.removeDuplicates();
    PreparedLibraries prepared;
    QStringList missing;
    QSet<QString> seenHashes;
    for (const auto &value : metadata.value("libraries").toArray()) {
        checkpoint(cancel);
        const auto library = value.toObject();
        if (!libraryAllowed(library)) continue;
        const auto artifact = library.value("downloads").toObject().value("artifact").toObject();
        // Old launcher metadata stores native-only classifiers separately. Reports
        // use the ordinary Java artifacts; no game window or audio is started.
        if (artifact.isEmpty() && library.value("downloads").toObject().contains("classifiers")) continue;
        const auto relative = artifact.value("path").toString();
        const auto hash = artifact.value("sha1").toString();
        require(safeLibraryPath(relative) && QRegularExpression("^[a-f0-9]{40}$").match(hash).hasMatch(),
                "版本信息含有无效的依赖路径或校验值：" + library.value("name").toString());
        if (seenHashes.contains(hash)) continue;
        seenHashes.insert(hash);
        const QString cached = cache + "/libraries/" + hash + ".jar";
        QString found;
        for (const auto &root : roots) {
            for (const auto &candidate : {root + "/" + relative, root + "/" + hash + ".jar"}) {
                if (QFileInfo(candidate).isFile() && sha1(candidate, cancel) == hash) {
                    found = QFileInfo(candidate).absoluteFilePath();
                    break;
                }
            }
            if (!found.isEmpty()) break;
        }
        if (found.isEmpty() && QFileInfo(cached).isFile() && sha1(cached, cancel) == hash) found = cached;
        if (found.isEmpty()) {
            if (!allowNetwork) { missing << relative; continue; }
            require(officialUrl(QUrl(artifact.value("url").toString())), "依赖包含非官方或非 HTTPS 下载地址：" + relative);
            prepared.downloads.append(artifact);
            continue;
        }
        prepared.paths << QDir::toNativeSeparators(QFileInfo(found).absoluteFilePath());
    }
    require(missing.isEmpty(), QString("缺少或损坏 %1 个依赖文件。请开启“允许联网补齐缺失文件”，或在高级选项指定已有依赖目录。\n%2%3")
            .arg(missing.size()).arg(missing.mid(0, 12).join('\n'))
            .arg(missing.size() > 12 ? "\n……" : ""));
    prepared.paths.removeDuplicates();
    require(!prepared.paths.isEmpty() || !prepared.downloads.isEmpty(), "未找到可用于生成物品表的客户端依赖。");
    return prepared;
}

QJsonArray generatedItems(const QString &cache, const QJsonObject &metadata, const QString &clientJar,
                          const QString &clientHash, const QVariantMap &options,
                          const Cancellation &cancel, const Progress &progress)
{
    const bool useServer = options.value("generator").toString() == "server";
    const bool allowNetwork = options.value("allowNetwork", true).toBool();
    const auto server = metadata.value("downloads").toObject().value("server").toObject();
    const auto hash = useServer ? server.value("sha1").toString() : clientHash;
    require(QRegularExpression("^[a-f0-9]{40}$").match(hash).hasMatch(), "该版本缺少生成物品表所需的文件校验信息。");
    const QString hashField = useServer ? "serverSha1" : "clientSha1";
    const QString reportsCache = cache + "/reports/" + hash + (useServer ? "" : "-client");
    QString error;
    const auto complete = readObject(reportsCache + "/complete.json");
    if (complete.value(hashField).toString() == hash && complete.value("componentsVersion").toInt() == 1) {
        const auto entries = parseItemReports(readObject(reportsCache + "/registries.json"),
                                             readObject(reportsCache + "/items.json"), &error);
        if (!entries.isEmpty()) return entries;
    }
    const int requiredJava = metadata.value("javaVersion").toObject().value("majorVersion").toInt(8);
    PreparedLibraries libraries;
    if (!useServer) {
        progress(12, "正在检查客户端依赖，优先复用本地文件…");
        libraries = clientLibraries(cache, metadata, options.value("sourcePath", clientJar).toString(),
                                     options.value("librariesPath").toString(), allowNetwork, cancel);
    }
    progress(12, "正在查找适合该版本的 Java…");
    const QString java = javaExecutable(options.value("javaPath").toString(), requiredJava, cancel,
                                        installationRoots(options.value("sourcePath", clientJar).toString()));
    QTemporaryDir generation(cache + "/generate-XXXXXX");
    require(generation.isValid(), "无法创建数据生成目录。");
    const QString output = generation.path() + "/generated";
    QStringList arguments;
    if (useServer) {
        progress(16, "正在准备手动选择的服务端备用生成器…");
        const QString serverJar = gameFile(cache, server, cancel, progress, 16, allowNetwork);
        const auto bundled = run(tarExecutable(), {"-xOf", serverJar, "META-INF/versions.list"},
                                 generation.path(), 30000, cancel);
        if (bundled.code == 0 && !bundled.output.trimmed().isEmpty())
            arguments << "-DbundlerMainClass=net.minecraft.data.Main" << "-jar" << serverJar;
        else
            arguments << "-cp" << serverJar << "net.minecraft.data.Main";
    } else {
        for (const auto &value : libraries.downloads) {
            const auto artifact = value.toObject();
            const auto cached = cache + "/libraries/" + artifact.value("sha1").toString() + ".jar";
            progress(16, "正在补齐依赖：" + artifact.value("path").toString());
            download(QUrl(artifact.value("url").toString()), cached, artifact.value("sha1").toString(), cancel, progress, 16);
            libraries.paths << QDir::toNativeSeparators(QFileInfo(cached).absoluteFilePath());
        }
        auto classpath = libraries.paths;
        classpath.prepend(QDir::toNativeSeparators(QFileInfo(clientJar).absoluteFilePath()));
        arguments << "-cp" << classpath.join(QDir::listSeparator()) << "net.minecraft.data.Main";
    }
    arguments << "--reports" << "--output" << output;
    progress(24, "正在从游戏注册表生成完整物品清单…");
    const auto generated = run(java, arguments, generation.path(), 300000, cancel, progress, 24);
    require(generated.code == 0, QString("游戏数据生成失败。建议为该版本选择 Java %1。\n%2")
            .arg(requiredJava).arg(QString::fromUtf8(generated.output.right(6000))));
    const auto registries = readObject(output + "/reports/registries.json");
    const auto items = readObject(output + "/reports/items.json");
    auto entries = parseItemReports(registries, items, &error);
    require(!entries.isEmpty(), "无法识别该版本生成的物品报告：" + error);
    // 26.1+ writes default components per registry entry, rather than items.json.
    for (int i = 0; i < entries.size(); ++i) {
        auto entry = entries[i].toObject();
        const QString id = entry.value("name").toString();
        const auto parts = id.split(':');
        for (const auto &prefix : {QString("minecraft/components/item/"), QString("components/minecraft/item/"), QString("default_components/minecraft/item/")}) {
            const auto defaults = readObject(output + "/reports/" + prefix + parts[1] + ".json");
            if (!defaults.isEmpty()) {
                entry.insert("components", defaults.value("components").isObject()
                             ? defaults.value("components") : QJsonValue(defaults));
                entries[i] = entry;
                break;
            }
        }
    }
    // Preserve an independent normalized report as well as raw provenance.
    QJsonObject normalized;
    for (const auto &entry : entries) {
        const auto object = entry.toObject();
        normalized.insert(object.value("name").toString(), QJsonObject{{"components", object.value("components")}});
    }
    writeJson(reportsCache + "/registries.json", registries);
    writeJson(reportsCache + "/items.json", normalized);
    writeJson(reportsCache + "/complete.json", {{hashField, hash}, {"version", metadata.value("id")}, {"componentsVersion", 1}});
    return entries;
}

QJsonObject officialMetadata(const QString &cache, const QString &version, bool allowNetwork,
                             const Cancellation &cancel)
{
    for (int attempt = 0; attempt < (allowNetwork ? 2 : 1); ++attempt) {
        const auto source = manifest(cache, cancel, attempt != 0, allowNetwork);
        for (const auto &candidate : parseVersions(source)) {
            if (candidate.toMap().value("id").toString() != version) continue;
            for (const auto &entry : source.value("versions").toArray())
                if (entry.toObject().value("id").toString() == version)
                    return versionMetadata(cache, entry.toObject(), cancel, allowNetwork);
        }
    }
    throw std::runtime_error("未找到该原版版本。请刷新在线版本列表，或选择包含版本 JSON 的本地安装；支持 Java 原版 1.13 起的版本。");
}

QJsonObject completedCatalog(const QString &root, const QString &pack)
{
    if (!QRegularExpression("^packs/[a-f0-9]{40}-r[0-9]+-[a-f0-9-]+$").match(pack).hasMatch()) return {};
    const auto catalog = readObject(root + "/" + pack + "/catalog.json");
    return catalog.value("schemaVersion").toInt() == CatalogSchema && !catalog.value("items").toArray().isEmpty()
            ? catalog : QJsonObject{};
}

QVariantMap packReport(const QJsonObject &catalog)
{
    auto report = catalog.toVariantMap();
    report.remove("items");
    report.insert("ok", true);
    report.insert("message", "已启用 Minecraft " + catalog.value("gameVersion").toString() + " 物品资源。");
    return report;
}

QVariantMap activateCached(const QString &root, const QString &hash, const QString &version,
                           const Cancellation &cancel)
{
    const auto cached = readObject(root + "/cache/packs/" + hash + "-r" + QString::number(RendererVersion) + ".json")
                        .value("pack").toString();
    const auto catalog = completedCatalog(root, cached);
    if (catalog.value("clientSha1").toString() != hash || catalog.value("rendererVersion").toInt() != RendererVersion
        || catalog.value("gameVersion").toString() != version) return {};
    checkpoint(cancel);
    QString error;
    require(activatePack(root, cached, &error), error);
    return packReport(catalog);
}

} // namespace

QVariantMap inspectLocalInstallation(const QString &sourcePath, const Cancellation &cancel)
{
    QVariantMap result{{"sourcePath", sourcePath}};
    try {
        const auto installation = localInstallation(sourcePath, cancel);
        result.insert("ok", true);
        result.insert("version", installation.version);
        result.insert("clientJar", installation.jar);
        result.insert("count", installation.count);
        result.insert("profile", installation.profile);
        result.insert("message", installation.count > 1
                      ? QString("发现 %1 个 Minecraft 版本，将导入最新的 %2 基础资源。也可直接选择目标版本的 JAR。").arg(installation.count).arg(installation.version)
                      : installation.profile.isEmpty() ? "已识别 Minecraft " + installation.version
                      : "已识别整合包的 Minecraft " + installation.version + " 基础资源（不含模组物品）");
    } catch (const std::exception &error) {
        result.insert("ok", false);
        result.insert("cancelled", cancel && cancel->load());
        result.insert("message", QString::fromUtf8(error.what()));
    }
    return result;
}

QString localPath(const QString &path)
{
    const QUrl url(path);
    return url.isLocalFile() ? url.toLocalFile() : path;
}

bool validItemId(const QString &id)
{
    static const QRegularExpression pattern("^[a-z0-9_.-]+:[a-z0-9_./-]+$");
    if (!pattern.match(id).hasMatch()) return false;
    const auto nameSpace = id.left(id.indexOf(':'));
    if (nameSpace == "." || nameSpace == "..") return false;
    const auto path = id.mid(id.indexOf(':') + 1);
    if (path.startsWith('/') || path.endsWith('/')) return false;
    for (const auto &segment : path.split('/'))
        if (segment.isEmpty() || segment == "." || segment == "..") return false;
    return true;
}

QJsonArray parseItemReports(const QJsonObject &registries, const QJsonObject &items, QString *error)
{
    if (error) error->clear();
    QJsonObject registered = registries.value("minecraft:item").toObject().value("entries").toObject();
    const bool hasRegistry = !registered.isEmpty();
    if (!hasRegistry) registered = items;
    if (!registered.contains("minecraft:air")) {
        if (error) *error = "物品报告不含空气注册项，无法确认清单完整性。";
        return {};
    }
    QStringList names = registered.keys();
    names.sort();
    QJsonArray entries;
    for (const auto &name : names) {
        if (!validItemId(name) || !name.startsWith("minecraft:")) {
            if (error) *error = "报告包含无效或非原版物品标识。";
            return {};
        }
        const auto value = registered.value(name);
        // 1.13 items.json maps IDs to numbers. Newer reports map them to objects.
        if (!value.isDouble() && !value.isObject()) {
            if (error) *error = "未知的物品报告结构。";
            return {};
        }
        const auto defaults = items.value(name).toObject().value("components").toObject();
        entries.append(QJsonObject{{"name", name}, {"components", defaults}});
    }
    if (entries.isEmpty() && error) *error = "报告没有物品注册数据。";
    return entries;
}

QVariantList parseVersions(const QJsonObject &source)
{
    QVariantList result;
    for (const auto &value : source.value("versions").toArray()) {
        const auto entry = value.toObject();
        const auto id = entry.value("id").toString();
        const auto type = entry.value("type").toString();
        if (type != "release" && type != "snapshot") continue;
        if (!QRegularExpression("^[A-Za-z0-9_.+-]+$").match(id).hasMatch()) continue;
        const auto date = QDateTime::fromString(entry.value("releaseTime").toString(), Qt::ISODate);
        if (!date.isValid() || date.date() < QDate(2018, 7, 18)) continue;
        result.append(QVariantMap{{"id", id}, {"type", type}, {"releaseTime", date},
                                  {"label", id + (type == "snapshot" ? " · 测试版" : "")}});
    }
    std::stable_sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("releaseTime").toDateTime() > b.toMap().value("releaseTime").toDateTime();
    });
    return result;
}

QVariantMap fetchVersions(const QString &itemsRoot, const Cancellation &cancel, bool allowNetwork)
{
    try {
        const auto source = manifest(localPath(itemsRoot) + "/cache", cancel, allowNetwork, allowNetwork);
        return {{"ok", true}, {"versions", parseVersions(source)},
                {"message", !allowNetwork ? "使用已缓存的官方版本列表。" : source.value("xcshopOffline").toBool()
                     ? "网络不可用，使用已缓存的官方版本列表。" : "已更新官方版本列表。"}};
    } catch (const std::exception &error) {
        return {{"ok", false}, {"message", QString::fromUtf8(error.what())}};
    }
}

QString activePack(const QString &itemsRoot)
{
    const auto pointer = readObject(itemsRoot + "/active.json");
    const auto path = pointer.value("pack").toString();
    if (pointer.value("schemaVersion").toInt() != CatalogSchema
        || !QRegularExpression("^packs/[a-f0-9]{40}-r[0-9]+-[a-f0-9-]+$").match(path).hasMatch()) return {};
    return path;
}

bool activatePack(const QString &itemsRoot, const QString &relativePack, QString *error)
{
    try {
        require(QRegularExpression("^packs/[a-f0-9]{40}-r[0-9]+-[a-f0-9-]+$").match(relativePack).hasMatch(), "无效的资源包路径。");
        const auto catalog = completedCatalog(itemsRoot, relativePack);
        require(!catalog.isEmpty(), "资源包未完成或已损坏，无法启用。");
        writeJson(itemsRoot + "/active.json", {{"schemaVersion", CatalogSchema}, {"pack", relativePack},
                                              {"gameVersion", catalog.value("gameVersion")}});
        return true;
    } catch (const std::exception &exception) {
        if (error) *error = QString::fromUtf8(exception.what());
        return false;
    }
}

QVariantList importedPacks(const QString &itemsRoot)
{
    const auto root = localPath(itemsRoot);
    const auto current = activePack(root);
    QVariantList packs;
    const QDir directory(root + "/packs");
    for (const auto &folder : directory.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (folder.isSymLink()) continue;
        const auto relative = "packs/" + folder.fileName();
        const auto catalog = completedCatalog(root, relative);
        if (catalog.value("gameVersion").toString().isEmpty()) continue;
        packs.append(QVariantMap{{"pack", relative}, {"version", catalog.value("gameVersion").toString()},
            {"itemCount", catalog.value("items").toArray().size()}, {"active", relative == current},
            {"currentRenderer", catalog.value("rendererVersion").toInt() == RendererVersion},
            {"createdAt", catalog.value("createdAt").toString(folder.lastModified().toUTC().toString(Qt::ISODate))}});
    }
    std::sort(packs.begin(), packs.end(), [](const QVariant &a, const QVariant &b) {
        const auto left = a.toMap(), right = b.toMap();
        for (const auto &key : {"active", "currentRenderer"})
            if (left.value(key).toBool() != right.value(key).toBool()) return left.value(key).toBool();
        return left.value("createdAt").toString() > right.value("createdAt").toString();
    });
    QSet<QString> seen;
    QVariantList versions;
    for (const auto &pack : packs) {
        const auto version = pack.toMap().value("version").toString();
        if (seen.contains(version)) continue;
        seen.insert(version);
        versions.append(pack);
    }
    return versions;
}

QVariantMap switchPack(const QString &itemsRoot, const QString &relativePack)
{
    try {
        const auto root = QDir(localPath(itemsRoot)).absolutePath();
        require(!itemsRoot.trimmed().isEmpty() && QDir().mkpath(root + "/cache"), "无法访问物品资源目录。");
        QLockFile lock(root + "/cache/import.lock");
        require(lock.tryLock(), "正在导入物品资源，请稍后切换版本。");
        const auto catalog = completedCatalog(root, relativePack);
        require(!catalog.isEmpty() && !catalog.value("gameVersion").toString().isEmpty(), "该资源包已不存在或未完成，请重新导入。");
        QString error;
        require(activatePack(root, relativePack, &error), error);
        return packReport(catalog);
    } catch (const std::exception &error) {
        return {{"ok", false}, {"message", QString::fromUtf8(error.what())}};
    }
}

QVariantMap importGame(const QVariantMap &options, const Cancellation &cancel, const Progress &progress)
{
    QVariantMap failure;
    try {
        checkpoint(cancel);
        const QString root = QDir(localPath(options.value("itemsRoot").toString())).absolutePath();
        require(!options.value("itemsRoot").toString().isEmpty() && QDir().mkpath(root + "/cache"), "无法创建物品资源目录。");
        QLockFile lock(root + "/cache/import.lock");
        require(lock.tryLock(), "另一个窗口正在导入此资源目录，请稍后重试。");
        const QString cache = root + "/cache";
        const bool allowNetwork = options.value("allowNetwork", true).toBool();
        const QString generator = options.value("generator", "client").toString();
        require(generator == "client" || generator == "server", "无效的数据生成方式。");
        const QString source = options.value("source", options.value("clientJar").toString().isEmpty() ? "download" : "local").toString();
        require(source == "local" || source == "download", "无效的导入来源。");
        const bool fromLocal = source == "local";
        QString version = options.value("version").toString().trimmed();
        QString jar, clientHash;
        QJsonObject metadata;
        if (fromLocal) {
            progress(1, "正在识别本地游戏版本…");
            const auto installation = localInstallation(options.value("sourcePath", options.value("clientJar")).toString(), cancel);
            jar = installation.jar;
            version = installation.version; // Never use a stale online version for a local file.
            clientHash = sha1(jar, cancel);
            if (!options.value("rebuild").toBool()) {
                const auto cached = activateCached(root, clientHash, version, cancel);
                if (!cached.isEmpty()) return cached;
            }
            metadata = installation.metadata;
            if (metadata.value("id").toString() != version) metadata = {};
            if (metadata.value("downloads").toObject().value("client").toObject().value("sha1").toString().isEmpty())
                metadata = readObject(cache + "/versions/" + version + ".json");
            if (metadata.value("id").toString() != version
                || metadata.value("downloads").toObject().value("client").toObject().value("sha1").toString().isEmpty()
                || (allowNetwork && generator == "client" && metadata.value("libraries").toArray().isEmpty()))
                metadata = officialMetadata(cache, version, allowNetwork, cancel);
            if (!metadata.contains("javaVersion") && installation.embedded.value("java_version").toInt() > 0)
                metadata.insert("javaVersion", QJsonObject{{"majorVersion", installation.embedded.value("java_version")}});
        } else {
            require(!version.isEmpty(), "请选择要在线下载的 Minecraft 版本。");
            progress(3, "正在读取 " + version + " 的官方版本信息…");
            metadata = officialMetadata(cache, version, allowNetwork, cancel);
        }
        require(vanillaMetadata(metadata), "无法解析基础游戏配置。可直接选择整合包内的原版游戏 JAR 或基础版本目录。");
        const auto client = metadata.value("downloads").toObject().value("client").toObject();
        const QString expectedHash = client.value("sha1").toString();
        require(QRegularExpression("^[a-f0-9]{40}$").match(expectedHash).hasMatch(), "客户端校验信息无效。");
        if (!jar.isEmpty()) require(clientHash == expectedHash,
                     "所选 JAR 与该版本的原版游戏本体不一致。可选择整合包目录以查找基础版本；暂不支持修改过的游戏本体。");
        clientHash = expectedHash;
        const QString index = cache + "/packs/" + clientHash + "-r" + QString::number(RendererVersion) + ".json";
        QString error;
        if (!options.value("rebuild").toBool()) {
            const auto cached = activateCached(root, clientHash, version, cancel);
            if (!cached.isEmpty()) return cached;
        }
        if (jar.isEmpty()) jar = gameFile(cache, client, cancel, progress, 6, allowNetwork);
        const auto server = metadata.value("downloads").toObject().value("server").toObject();
        if (generator == "client" && QRegularExpression("^[a-f0-9]{40}$").match(server.value("sha1").toString()).hasMatch()
            && officialUrl(QUrl(server.value("url").toString()))) {
            failure.insert("canUseServer", true);
            failure.insert("requestSource", fromLocal ? "local" : "download");
            failure.insert("requestPath", fromLocal ? options.value("sourcePath", options.value("clientJar")).toString().trimmed() : "");
            failure.insert("requestVersion", fromLocal ? "" : version);
            failure.insert("serverSize", server.value("size").toVariant());
            const auto cachedServer = cache + "/downloads/" + server.value("sha1").toString() + ".jar";
            failure.insert("serverCached", QFileInfo(cachedServer).isFile() && sha1(cachedServer, cancel) == server.value("sha1").toString());
        }
        auto generationOptions = options;
        if (!fromLocal) generationOptions.insert("sourcePath", jar);
        auto entries = generatedItems(cache, metadata, jar, clientHash, generationOptions, cancel, progress);
        QTemporaryDir staging(root + "/cache/import-XXXXXX");
        require(staging.isValid(), "无法创建导入临时目录。");
        progress(35, "正在解压客户端显示资源…");
        // Only verified official clients reach extraction. Both data reports and
        // icon output remain in staging until the complete catalog is written.
        const auto extracted = run(tarExecutable(), {"-xf", jar, "assets/minecraft"}, staging.path(), 120000, cancel);
        require(extracted.code == 0 && QDir(staging.path() + "/assets/minecraft").exists(), "无法解压客户端资源，请确认 tar 可读取 ZIP/JAR 文件。");
        const QString pack = staging.path() + "/pack";
        const QString assets = staging.path() + "/assets/minecraft";
        require(QDir().mkpath(pack + "/assets/minecraft"), "无法创建图标目录。");
        int rendered = 0, approximate = 0, missing = 0;
        for (int i = 0; i < entries.size(); ++i) {
            checkpoint(cancel);
            if (i % 20 == 0) progress(40 + i * 54 / qMax(1, entries.size()),
                                    QString("正在生成物品图标：%1 / %2").arg(i).arg(entries.size()));
            auto item = entries[i].toObject();
            const QString id = item.value("name").toString();
            const QString name = id.mid(QStringLiteral("minecraft:").size());
            const QString output = pack + "/assets/minecraft/" + name + ".png";
            require(QDir().mkpath(QFileInfo(output).absolutePath()), "无法创建物品图标目录。");
            const auto icon = renderItem(assets, id, item.value("components").toObject(), output);
            item.insert("iconStatus", icon.status);
            if (!icon.reason.isEmpty()) item.insert("iconReason", icon.reason);
            if (icon.status == "rendered") ++rendered;
            else if (icon.status == "approximate") ++approximate;
            else if (icon.status == "missing") ++missing;
            entries[i] = item;
        }
        QJsonObject catalog{{"schemaVersion", CatalogSchema}, {"rendererVersion", RendererVersion},
            {"gameVersion", version}, {"clientSha1", clientHash},
            {"source", "mojang"}, {"generator", generator}, {"registryComplete", true}, {"itemCount", entries.size()},
            {"rendered", rendered}, {"approximate", approximate}, {"missing", missing},
            {"createdAt", QDateTime::currentDateTimeUtc().toString(Qt::ISODate)}, {"items", entries}};
        if (generator == "server") catalog.insert("serverSha1", server.value("sha1"));
        writeJson(pack + "/catalog.json", catalog);
        checkpoint(cancel);
        progress(96, "正在保存并启用完整资源包…");
        const QString relative = "packs/" + clientHash + "-r" + QString::number(RendererVersion)
                               + "-" + QUuid::createUuid().toString(QUuid::WithoutBraces);
        require(QDir().mkpath(root + "/packs"), "无法创建资源包目录。");
        bool moved = false;
        for (int attempt = 0; attempt < 10 && !moved; ++attempt) {
            checkpoint(cancel);
            moved = QDir().rename(pack, root + "/" + relative);
            if (!moved) QThread::msleep(100); // Windows scanners can briefly hold newly written icons.
        }
        require(moved, "无法保存完整资源包，请检查目录写入权限及文件是否被占用。");
        checkpoint(cancel);
        require(activatePack(root, relative, &error), error);
        // Cache indexes are optional; failure here must not misreport activation.
        try { writeJson(index, {{"pack", relative}}); } catch (...) {}
        auto report = catalog.toVariantMap();
        report.remove("items");
        report.insert("ok", true);
        report.insert("message", QString("已导入 Minecraft %1：%2 项注册物品，%3 个默认图标，%4 个近似图标，%5 项缺少图标。")
                      .arg(version).arg(entries.size()).arg(rendered).arg(approximate).arg(missing));
        progress(100, report.value("message").toString());
        return report;
    } catch (const std::exception &error) {
        const auto message = QString::fromUtf8(error.what());
        if (message.startsWith("未找到可用的 Java") || message.startsWith("无法启动"))
            failure.insert("canUseServer", false);
        failure.insert("ok", false);
        failure.insert("cancelled", cancel && cancel->load());
        failure.insert("message", message);
        return failure;
    }
}
} // namespace MinecraftImport
