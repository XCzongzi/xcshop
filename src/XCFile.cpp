#include "XCFile.h"
#include <QDesktopServices>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QDirIterator>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QCoreApplication>
#include <QTextStream>
#include <QUrl>

XCFile::XCFile() = default;


QString XCFile::localPath(const QString& path){
    const QUrl url(path);
    return url.isLocalFile() ? url.toLocalFile() : path;
}

bool XCFile::write(const QString& filePath,const QString& content){
    const QString path = localPath(filePath);
    if (!QDir().mkpath(QFileInfo(path).absolutePath()))
        return false;
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)){
        QTextStream out(&file);
        out << content;
        return true;
    }
    return false;
}

bool XCFile::writeAtomic(const QString& filePath, const QString& content){
    const QString path = localPath(filePath);
    if (!QDir().mkpath(QFileInfo(path).absolutePath()))
        return false;
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream out(&file);
    out << content;
    out.flush();
    if (out.status() != QTextStream::Ok) {
        file.cancelWriting();
        return false;
    }
    return file.commit();
}

QString XCFile::read(const QString& filePath){
    QFile file(localPath(filePath));
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)){
        QTextStream in(&file);
        return in.readAll();
    }
    return "";
}

bool XCFile::exists(const QString& filePath){
    QFileInfo info(localPath(filePath));
    return info.exists() && info.isFile();
}

bool XCFile::isDirectory(const QString& path){
    return QFileInfo(localPath(path)).isDir();
}

bool XCFile::folder(const QString& folderPath){
    QDir dir(localPath(folderPath));
    if (!dir.exists()){
        return dir.mkpath(".");
    }
    return true;
}


bool XCFile::rename(const QString& oldPath, const QString& newPath){
    const QString source = localPath(oldPath);
    const QString destination = localPath(newPath);
    if (source == destination || QFileInfo::exists(destination))
        return false;
    return QFileInfo(source).isDir() ? QDir().rename(source, destination)
                                   : QFile::rename(source, destination);
}

bool XCFile::copy(const QString& sourcePath, const QString& destinationPath){
    const QString source = localPath(sourcePath);
    const QString destination = localPath(destinationPath);
    QFileInfo destinationInfo(destination);
    if (!QDir().mkpath(destinationInfo.absolutePath()))
        return false;
    if (QFile::exists(destination) && !QFile::remove(destination))
        return false;
    return QFile::copy(source, destination);
}

QString XCFile::availableFilePath(const QDir& directory, const QFileInfo& sourceInfo){
    const QString originalPath = directory.filePath(sourceInfo.fileName());
    if (!QFile::exists(originalPath))
        return originalPath;

    QString baseName = sourceInfo.isDir() ? sourceInfo.fileName()
                                          : sourceInfo.completeBaseName();
    const QRegularExpression numberedSuffix(QStringLiteral("^(.*) - [0-9]+$"));
    const QRegularExpressionMatch match = numberedSuffix.match(baseName);
    if (match.hasMatch())
        baseName = match.captured(1);

    const QString suffix = sourceInfo.isDir() ? QString() : sourceInfo.suffix();
    for (int number = 1; ; ++number) {
        const QString candidateName = baseName + QStringLiteral(" - ")
                + QString::number(number) + (suffix.isEmpty() ? QString() : "." + suffix);
        const QString candidatePath = directory.filePath(candidateName);
        if (!QFile::exists(candidatePath))
            return candidatePath;
    }
}

QString XCFile::copyToDirectory(const QString& sourcePath, const QString& directoryPath){
    const QString source = localPath(sourcePath);
    const QFileInfo sourceInfo(source);
    QDir destinationDirectory(localPath(directoryPath));
    if (!sourceInfo.isFile() || (!destinationDirectory.exists() && !destinationDirectory.mkpath(".")))
        return {};

    const QString destination = availableFilePath(destinationDirectory, sourceInfo);
    return QFile::copy(source, destination) ? QDir::cleanPath(destination) : QString();
}

bool XCFile::copyDirectory(const QString& sourcePath, const QString& destinationPath){
    QDir sourceDirectory(sourcePath);
    if (!sourceDirectory.exists() || !QDir().mkpath(destinationPath))
        return false;

    const QFileInfoList entries = sourceDirectory.entryInfoList(
                QDir::NoDotAndDotDot | QDir::AllEntries);
    for (const QFileInfo& entry : entries) {
        const QString destination = QDir(destinationPath).filePath(entry.fileName());
        if (entry.isDir()) {
            if (!copyDirectory(entry.absoluteFilePath(), destination))
                return false;
        } else if (!QFile::copy(entry.absoluteFilePath(), destination)) {
            return false;
        }
    }
    return true;
}

QString XCFile::moveToDirectory(const QString& sourcePath, const QString& directoryPath){
    const QString source = QDir::cleanPath(localPath(sourcePath));
    const QFileInfo sourceInfo(source);
    QDir destinationDirectory(localPath(directoryPath));
    if (!sourceInfo.exists() || (!destinationDirectory.exists() && !destinationDirectory.mkpath(".")))
        return {};
    if (QDir::cleanPath(sourceInfo.absolutePath()) == QDir::cleanPath(destinationDirectory.absolutePath()))
        return source;

    const QString destinationRoot = QDir::cleanPath(destinationDirectory.absolutePath());
    const QString sourceRoot = QDir::cleanPath(sourceInfo.absoluteFilePath());
    if (sourceInfo.isDir() && (destinationRoot == sourceRoot
                               || destinationRoot.startsWith(sourceRoot + "/")))
        return {};

    const QString destination = availableFilePath(destinationDirectory, sourceInfo);
    if (sourceInfo.isDir()) {
        if (QDir().rename(source, destination))
            return QDir::cleanPath(destination);
        if (!copyDirectory(source, destination)) {
            QDir(destination).removeRecursively();
            return {};
        }
        if (QDir(source).removeRecursively())
            return QDir::cleanPath(destination);
        QDir(destination).removeRecursively();
        return {};
    }

    if (QFile::rename(source, destination))
        return QDir::cleanPath(destination);
    if (!QFile::copy(source, destination))
        return {};
    if (QFile::remove(source))
        return QDir::cleanPath(destination);
    QFile::remove(destination);
    return {};
}

bool XCFile::remove_file(const QString& filePath){
    return QFile::remove(localPath(filePath));
}

QStringList XCFile::filesInDirectory(const QString& directoryPath){
    QStringList files;
    QDirIterator iterator(localPath(directoryPath), QDir::Files,
                          QDirIterator::Subdirectories);
    while (iterator.hasNext())
        files.append(QDir::cleanPath(iterator.next()));
    return files;
}

bool XCFile::removeDirectory(const QString& directoryPath){
    QDir directory(localPath(directoryPath));
    return directory.exists() && directory.removeRecursively();
}

QString XCFile::clone(const QString& filePath){
    const QString source = localPath(filePath);
    return copyToDirectory(source, QFileInfo(source).absolutePath());
}

bool XCFile::revealInFileManager(const QString& filePath){
    const QString path = localPath(filePath);
    const QFileInfo info(path);
    if (!info.exists())
        return false;

#ifdef Q_OS_WIN
    if (info.isDir())
        return QProcess::startDetached(QStringLiteral("explorer.exe"),
                                       {QDir::toNativeSeparators(info.absoluteFilePath())});
    return QProcess::startDetached(QStringLiteral("explorer.exe"),
                                   {QStringLiteral("/select,"),
                                    QDir::toNativeSeparators(info.absoluteFilePath())});
#elif defined(Q_OS_MACOS)
    return QProcess::startDetached(QStringLiteral("open"),
                                   {QStringLiteral("-R"), info.absoluteFilePath()});
#else
    return QDesktopServices::openUrl(QUrl::fromLocalFile(info.isDir()
                                                         ? info.absoluteFilePath()
                                                         : info.absolutePath()));
#endif
}

QString XCFile::runtimePath(){
    const QString path = QCoreApplication::applicationDirPath();
    QDir().mkpath(path);
    return path;
}

QVariantList XCFile::backgroundImages(){
    const QDir directory(runtimePath() + "/backgrounds");
    QVariantList images;
    for (const auto& info : directory.entryInfoList(QDir::Files | QDir::NoSymLinks, QDir::Name)) {
        images.append(QVariantMap{{"name", info.completeBaseName()},
                                  {"source", QUrl::fromLocalFile(info.absoluteFilePath()).toString()}});
    }
    return images;
}

QString XCFile::importBackgroundImage(const QString& sourcePath){
    QImageReader reader(localPath(sourcePath));
    reader.setAutoTransform(true);
    if (!reader.canRead())
        return {};
    const QSize size = reader.size();
    if (size.isValid())
        reader.setScaledSize(size.scaled(QSize(256, 256), Qt::KeepAspectRatio));
    if (reader.read().isNull())
        return {};
    const QString copied = copyToDirectory(sourcePath, runtimePath() + "/backgrounds");
    if (!copied.isEmpty())
        QFile::setPermissions(copied, QFile::permissions(copied) | QFileDevice::WriteOwner | QFileDevice::WriteUser);
    return copied.isEmpty() ? QString() : QUrl::fromLocalFile(copied).toString();
}

bool XCFile::removeBackgroundImage(const QString& sourceUrl){
    const QFileInfo info(localPath(sourceUrl));
    const QDir directory(runtimePath() + "/backgrounds");
    // Only delete files owned by the background library, never an original import.
    if (info.isSymLink() || info.absoluteDir().absolutePath() != directory.absolutePath())
        return false;
    return QFile::remove(info.absoluteFilePath());
}
