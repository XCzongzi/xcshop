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
#include <QJsonDocument>
#include <QLockFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
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

QJsonObject manifest(const QString &cache, const Cancellation &cancel, bool refresh)
{
    const auto path = cache + "/manifest.json";
    auto cached = readObject(path);
    if (!refresh && !cached.value("versions").toArray().isEmpty()) return cached;
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

QJsonObject versionMetadata(const QString &cache, const QJsonObject &entry, const Cancellation &cancel)
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
    download(QUrl(entry.value("url").toString()), path, expected, cancel);
    const auto object = readObject(path);
    require(object.value("id").toString() == id && !object.value("downloads").toObject().isEmpty(),
            "官方版本元数据无效。");
    return object;
}

QString gameFile(const QString &cache, const QJsonObject &entry, const Cancellation &cancel,
                 const Progress &progress, int step)
{
    const QString hash = entry.value("sha1").toString();
    require(QRegularExpression("^[a-f0-9]{40}$").match(hash).hasMatch(), "官方文件缺少有效校验值。");
    const QString path = cache + "/downloads/" + hash + ".jar";
    if (!QFileInfo::exists(path) || sha1(path, cancel) != hash)
        download(QUrl(entry.value("url").toString()), path, hash, cancel, progress, step);
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

QString detectVersion(const QString &jar, const Cancellation &cancel)
{
    const auto embedded = run(tarExecutable(), {"-xOf", jar, "version.json"},
                              QFileInfo(jar).absolutePath(), 30000, cancel);
    const auto object = QJsonDocument::fromJson(embedded.output).object();
    if (!object.value("id").toString().isEmpty()) return object.value("id").toString();
    // 1.13 predates embedded version.json. Launchers keep metadata beside JARs.
    const QFileInfo file(jar);
    const auto adjacent = readObject(file.absolutePath() + "/" + file.completeBaseName() + ".json");
    return adjacent.value("id").toString(file.completeBaseName());
}

QString javaExecutable(QString selected, int required, const Cancellation &cancel)
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

QJsonArray generatedItems(const QString &cache, const QJsonObject &metadata,
                          const QString &javaPath, const Cancellation &cancel, const Progress &progress)
{
    const auto server = metadata.value("downloads").toObject().value("server").toObject();
    const auto hash = server.value("sha1").toString();
    require(QRegularExpression("^[a-f0-9]{40}$").match(hash).hasMatch(), "该版本未提供官方服务端文件，无法生成完整物品清单。");
    const QString reportsCache = cache + "/reports/" + hash;
    QString error;
    const auto complete = readObject(reportsCache + "/complete.json");
    if (complete.value("serverSha1").toString() == hash && complete.value("componentsVersion").toInt() == 1) {
        const auto entries = parseItemReports(readObject(reportsCache + "/registries.json"),
                                             readObject(reportsCache + "/items.json"), &error);
        if (!entries.isEmpty()) return entries;
    }
    progress(16, "正在准备对应版本的官方服务端与物品注册数据…");
    const QString serverJar = gameFile(cache, server, cancel, progress, 16);
    const int requiredJava = metadata.value("javaVersion").toObject().value("majorVersion").toInt(8);
    const QString java = javaExecutable(javaPath, requiredJava, cancel);
    QTemporaryDir generation(cache + "/generate-XXXXXX");
    require(generation.isValid(), "无法创建数据生成目录。");
    const QString output = generation.path() + "/generated";
    const auto bundled = run(tarExecutable(), {"-xOf", serverJar, "META-INF/versions.list"},
                             generation.path(), 30000, cancel);
    QStringList arguments;
    if (bundled.code == 0 && !bundled.output.trimmed().isEmpty())
        arguments << "-DbundlerMainClass=net.minecraft.data.Main" << "-jar" << serverJar;
    else
        arguments << "-cp" << serverJar << "net.minecraft.data.Main";
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
    writeJson(reportsCache + "/complete.json", {{"serverSha1", hash}, {"version", metadata.value("id")}, {"componentsVersion", 1}});
    return entries;
}

} // namespace

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

QVariantMap fetchVersions(const QString &itemsRoot, const Cancellation &cancel)
{
    try {
        const auto source = manifest(localPath(itemsRoot) + "/cache", cancel, true);
        return {{"ok", true}, {"versions", parseVersions(source)},
                {"message", source.value("xcshopOffline").toBool() ? "网络不可用，使用已缓存的官方版本列表。" : "已更新官方版本列表。"}};
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
        const auto catalog = readObject(itemsRoot + "/" + relativePack + "/catalog.json");
        require(catalog.value("schemaVersion").toInt() == CatalogSchema && !catalog.value("items").toArray().isEmpty(), "资源包未完成，无法启用。");
        writeJson(itemsRoot + "/active.json", {{"schemaVersion", CatalogSchema}, {"pack", relativePack},
                                              {"gameVersion", catalog.value("gameVersion")}});
        return true;
    } catch (const std::exception &exception) {
        if (error) *error = QString::fromUtf8(exception.what());
        return false;
    }
}

QVariantMap importGame(const QVariantMap &options, const Cancellation &cancel, const Progress &progress)
{
    try {
        const QString root = QDir(localPath(options.value("itemsRoot").toString())).absolutePath();
        require(!options.value("itemsRoot").toString().isEmpty() && QDir().mkpath(root + "/cache"), "无法创建物品资源目录。");
        QLockFile lock(root + "/cache/import.lock");
        require(lock.tryLock(), "另一个窗口正在导入此资源目录，请稍后重试。");
        const QString cache = root + "/cache";
        const auto source = manifest(cache, cancel, false);
        QString version = options.value("version").toString().trimmed();
        QString jar = localPath(options.value("clientJar").toString().trimmed());
        if (!jar.isEmpty()) {
            require(QFileInfo(jar).isFile(), "本地客户端 JAR 不存在。");
            if (version.isEmpty()) version = detectVersion(jar, cancel);
        }
        require(!version.isEmpty(), "请选择 Minecraft 版本，或提供可识别版本的客户端 JAR。");
        QJsonObject selected;
        const auto supported = parseVersions(source);
        for (const auto &candidate : supported)
            if (candidate.toMap().value("id").toString() == version) {
                for (const auto &entry : source.value("versions").toArray())
                    if (entry.toObject().value("id").toString() == version) selected = entry.toObject();
                break;
            }
        require(!selected.isEmpty(), "未找到该版本。请刷新官方版本列表；支持范围为 Java 原版 1.13 起的正式版及后续测试版。");
        progress(3, "正在读取 " + version + " 的官方版本信息…");
        const auto metadata = versionMetadata(cache, selected, cancel);
        const auto client = metadata.value("downloads").toObject().value("client").toObject();
        const QString clientHash = client.value("sha1").toString();
        require(QRegularExpression("^[a-f0-9]{40}$").match(clientHash).hasMatch(), "官方客户端校验信息无效。");
        if (!jar.isEmpty()) require(sha1(jar, cancel) == clientHash,
                     "所选 JAR 与该版本的官方客户端不一致。请选择对应的原版客户端文件；暂不支持修改过的客户端或模组包。");
        const QString index = cache + "/packs/" + clientHash + "-r" + QString::number(RendererVersion) + ".json";
        const auto cached = readObject(index).value("pack").toString();
        const auto cachedCatalog = readObject(root + "/" + cached + "/catalog.json");
        QString error;
        if (!options.value("rebuild").toBool() && cachedCatalog.value("clientSha1").toString() == clientHash
            && cachedCatalog.value("rendererVersion").toInt() == RendererVersion) {
            checkpoint(cancel);
            require(activatePack(root, cached, &error), error);
            auto report = cachedCatalog.toVariantMap();
            report.remove("items");
            report.insert("ok", true);
            report.insert("message", "已启用缓存的 Minecraft " + version + " 物品资源。");
            return report;
        }
        if (jar.isEmpty()) jar = gameFile(cache, client, cancel, progress, 6);
        auto entries = generatedItems(cache, metadata, options.value("javaPath").toString(), cancel, progress);
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
            {"serverSha1", metadata.value("downloads").toObject().value("server").toObject().value("sha1")},
            {"source", "mojang"}, {"registryComplete", true}, {"itemCount", entries.size()},
            {"rendered", rendered}, {"approximate", approximate}, {"missing", missing},
            {"createdAt", QDateTime::currentDateTimeUtc().toString(Qt::ISODate)}, {"items", entries}};
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
        return {{"ok", false}, {"cancelled", cancel && cancel->load()},
                {"message", QString::fromUtf8(error.what())}};
    }
}
} // namespace MinecraftImport
