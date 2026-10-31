#include "BuildKitArchive.h"

#include <zlib.h>
#include <QtEndian>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QSet>
#include <QTimer>
#include <stdexcept>

namespace BuildKitArchive {
namespace {
constexpr qint64 maxArchive = 128 * 1024 * 1024;
constexpr qint64 maxExpanded = 256 * 1024 * 1024;
constexpr qint64 maxFile = 32 * 1024 * 1024;
void require(bool ok, const QString &error) {
    if (!ok) throw std::runtime_error(error.toUtf8().constData());
}
void checkpoint(const Cancellation &cancel) {
    require(!cancel->load(), "已取消获取套件。");
}
// The distribution uses ordinary single-volume ZIP (store/deflate). Read the
// central directory without normalizing its names, and bound inflate's output.
// ZIP64, encryption and legacy filename encodings are intentionally unsupported.
struct Entry {
    QString name;
    quint32 crc, compressed, size, offset;
    quint16 method;
    bool directory;
};
quint16 u16(const QByteArray &bytes, qsizetype offset) {
    require(offset >= 0 && offset + 2 <= bytes.size(), "ZIP 目录已损坏。");
    return qFromLittleEndian<quint16>(bytes.constData() + offset);
}
quint32 u32(const QByteArray &bytes, qsizetype offset) {
    require(offset >= 0 && offset + 4 <= bytes.size(), "ZIP 目录已损坏。");
    return qFromLittleEndian<quint32>(bytes.constData() + offset);
}
QList<Entry> readEntries(const QByteArray &bytes) {
    qsizetype end = bytes.size() - 22;
    for (; end >= qMax(qsizetype(0), bytes.size() - 65557); --end)
        if (u32(bytes, end) == 0x06054b50 && end + 22 + u16(bytes, end + 20) == bytes.size()) break;
    require(end >= 0 && end >= bytes.size() - 65557, "ZIP 无效或已损坏。");
    const auto count = u16(bytes, end + 10);
    const quint64 directorySize = u32(bytes, end + 12), directoryOffset = u32(bytes, end + 16);
    require(u16(bytes, end + 4) == 0 && u16(bytes, end + 6) == 0 && u16(bytes, end + 8) == count
            && count > 0 && count <= 10000 && directoryOffset + directorySize == quint64(end),
            "ZIP 目录无效，或使用了不支持的分卷 / ZIP64 格式。");
    QList<Entry> entries;
    qsizetype position = directoryOffset;
    for (int i = 0; i < count; ++i) {
        require(position + 46 <= end && u32(bytes, position) == 0x02014b50, "ZIP 目录已损坏。");
        const auto flags = u16(bytes, position + 8), method = u16(bytes, position + 10);
        const auto nameLength = u16(bytes, position + 28);
        const auto next = position + 46 + nameLength + u16(bytes, position + 30) + u16(bytes, position + 32);
        require(next <= end && u16(bytes, position + 34) == 0 && (flags & ~quint16(0x080e)) == 0
                && (method == 0 || method == 8), "ZIP 使用了不支持的压缩、加密或分卷格式。");
        const auto rawName = bytes.mid(position + 46, nameLength);
        const auto name = QString::fromUtf8(rawName);
        require(name.toUtf8() == rawName, "ZIP 文件名需使用 UTF-8 编码。");
        const auto attributes = u32(bytes, position + 38);
        const auto type = (attributes >> 16) & 0170000;
        require(type == 0 || type == 0100000 || type == 0040000, "ZIP 包含链接或非普通文件：" + name);
        const bool directory = name.endsWith('/');
        require(type != 0040000 || directory, "ZIP 目录属性无效：" + name);
        Entry entry{name, u32(bytes, position + 16), u32(bytes, position + 20),
                    u32(bytes, position + 24), u32(bytes, position + 42), method, directory};
        require(quint64(entry.offset) + 30 <= directoryOffset && u32(bytes, entry.offset) == 0x04034b50,
                "ZIP 文件头已损坏。");
        const auto offset = qsizetype(entry.offset);
        const quint64 payload = quint64(offset) + 30 + u16(bytes, offset + 26) + u16(bytes, offset + 28);
        require(u16(bytes, offset + 6) == flags && u16(bytes, offset + 8) == method
                && bytes.mid(offset + 30, u16(bytes, offset + 26)) == rawName
                && payload + entry.compressed <= directoryOffset, "ZIP 文件头与目录不一致。");
        if (directory) require(entry.size == 0, "ZIP 目录不能包含文件内容。");
        entries << entry;
        position = next;
    }
    require(position == end, "ZIP 目录长度无效。");
    return entries;
}
QByteArray fileData(const QByteArray &archive, const Entry &entry) {
    const auto offset = qsizetype(entry.offset);
    const auto start = offset + 30 + u16(archive, offset + 26) + u16(archive, offset + 28);
    QByteArray result;
    if (entry.method == 0) {
        require(entry.compressed == entry.size, "ZIP 文件大小无效。");
        result = archive.mid(start, entry.size);
    } else {
        result.resize(qMax(quint32(1), entry.size));
        z_stream stream{};
        stream.next_in = reinterpret_cast<Bytef *>(const_cast<char *>(archive.constData() + start));
        stream.avail_in = entry.compressed;
        stream.next_out = reinterpret_cast<Bytef *>(result.data());
        stream.avail_out = result.size();
        require(inflateInit2(&stream, -MAX_WBITS) == Z_OK, "无法初始化 ZIP 解压。");
        const auto status = inflate(&stream, Z_FINISH);
        const bool valid = status == Z_STREAM_END && stream.total_out == entry.size && stream.total_in == entry.compressed;
        inflateEnd(&stream);
        require(valid, "ZIP 文件损坏或解压大小与目录不符：" + entry.name);
        result.resize(entry.size);
    }
    require(::crc32(0, reinterpret_cast<const Bytef *>(result.constData()), result.size()) == entry.crc,
            "ZIP 文件校验失败：" + entry.name);
    return result;
}
void download(const QUrl &url, const QString &path, const Cancellation &cancel, const Progress &progress) {
    QFile output(path);
    require(output.open(QIODevice::WriteOnly), "无法创建套件下载临时文件。");
    QNetworkAccessManager network;
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    request.setRawHeader("User-Agent", "xcshop-kits");
    auto *reply = network.get(request);
    reply->setReadBufferSize(256 * 1024);
    QEventLoop loop;
    QString error;
    qint64 received = 0;
    auto read = [&] {
        const auto bytes = reply->readAll();
        received += bytes.size();
        if (received > maxArchive) error = "套件压缩包超过 128 MiB，已停止下载。";
        else if (output.write(bytes) != bytes.size()) error = "无法写入套件下载文件。";
        if (!error.isEmpty()) reply->abort();
    };
    QObject::connect(reply, &QNetworkReply::readyRead, &loop, read);
    QObject::connect(reply, &QNetworkReply::downloadProgress, &loop, [&](qint64 current, qint64 total) {
        if (total > maxArchive) { error = "套件压缩包超过 128 MiB，已停止下载。"; reply->abort(); }
        progress(total > 0 ? int(qMin(qint64(60), current * 60 / total)) : -1,
                 QString("正在下载套件 · %1 MiB").arg(current / 1048576.0, 0, 'f', 1));
    });
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer polling, deadline;
    QObject::connect(&polling, &QTimer::timeout, &loop, [&] { if (cancel->load()) reply->abort(); });
    QObject::connect(&deadline, &QTimer::timeout, &loop, [&] { error = "下载套件超时，请重试。"; reply->abort(); });
    polling.start(50);
    deadline.setSingleShot(true);
    deadline.start(120000);
    if (!reply->isFinished()) loop.exec();
    if (error.isEmpty() && reply->isOpen()) read();
    checkpoint(cancel);
    require(error.isEmpty(), error);
    require(reply->error() == QNetworkReply::NoError
            && reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 200,
            "下载套件失败：" + reply->errorString());
    require(output.flush(), "无法保存套件下载文件。");
}
}

QString prepare(const QString &source, const QUrl &downloadUrl, const QString &staging,
                const Cancellation &cancel, const Progress &progress) {
    checkpoint(cancel);
    if (!source.isEmpty() && QFileInfo(source).isDir()) return source;
    QString archive = source;
    if (source.isEmpty()) {
        progress(-1, "正在连接套件下载服务…");
        archive = staging + "/kits.zip";
        download(downloadUrl, archive, cancel, progress);
    }
    require(QFileInfo(archive).isFile() && QFileInfo(archive).size() <= maxArchive, "无法读取 ZIP，或压缩包超过 128 MiB。");
    QFile input(archive);
    require(input.open(QIODevice::ReadOnly), "无法读取套件 ZIP。");
    const auto bytes = input.read(maxArchive + 1);
    require(bytes.size() <= maxArchive, "套件压缩包超过 128 MiB。");
    const auto entries = readEntries(bytes);
    QSet<QString> names;
    qint64 expanded = 0;
    // Check every path before extracting; never let archive permissions or links
    // affect the filesystem. Accept kits/ at the top level or its contents directly.
    for (const auto &entry : entries) {
        auto name = entry.name;
        if (entry.directory) name.chop(1);
        require(!name.isEmpty() && !name.contains('\\') && !QDir::isAbsolutePath(name),
                "ZIP 包含无效路径或链接：" + name);
        for (const auto &part : name.split('/')) {
            // These restrictions also avoid aliases, device files and alternate
            // data streams when importing on Windows.
            static const QRegularExpression reserved("^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\\.|$)", QRegularExpression::CaseInsensitiveOption);
            require(!part.isEmpty() && part != "." && part != ".." && !part.endsWith('.') && !part.endsWith(' ')
                    && !part.contains(QRegularExpression("[<>:\"|?*\\x00-\\x1f]")) && !reserved.match(part).hasMatch(),
                    "ZIP 包含不安全的路径：" + name);
        }
        const auto key = name.toCaseFolded();
        require(!names.contains(key), "ZIP 包含重复路径：" + name);
        names.insert(key);
        require(entry.size <= maxFile && entry.size <= maxExpanded - expanded,
                "ZIP 解压大小超过限制（单文件 32 MiB，总计 256 MiB）。");
        expanded += entry.size;
    }
    const auto destination = staging + "/contents";
    int done = 0;
    for (const auto &entry : entries) {
        checkpoint(cancel);
        const auto path = QDir(destination).filePath(entry.name);
        ++done;
        if (done == 1 || done == entries.size() || done % qMax(qsizetype(1), entries.size() / 30) == 0)
            progress(60 + (done * 30 / entries.size()), "正在解压套件…");
        if (entry.directory) { require(QDir().mkpath(path), "无法创建解压目录。"); continue; }
        const auto contents = fileData(bytes, entry);
        require(QDir().mkpath(QFileInfo(path).absolutePath()), "无法创建解压目录。");
        QFile file(path);
        require(file.open(QIODevice::WriteOnly | QIODevice::NewOnly) && file.write(contents) == contents.size() && file.flush(),
                "无法解压文件：" + entry.name);
    }
    return QFileInfo(destination + "/templates").isDir() ? destination : destination + "/kits";
}
}
