#include <QObject>
#include <QtQml>    // QML_ELEMENT macro
#include <QDir>
#include <QFileInfo>
#include <QUrl>


class XCFile : public QObject {
    Q_OBJECT
    QML_ELEMENT     //注册至qml

public:
    XCFile();
    Q_INVOKABLE bool write(const QString& filePath,const QString& content);
    Q_INVOKABLE bool writeAtomic(const QString& filePath,const QString& content);
    Q_INVOKABLE QString read(const QString& filePath);
    Q_INVOKABLE bool exists(const QString& filePath);
    Q_INVOKABLE bool isDirectory(const QString& path);
    Q_INVOKABLE bool folder(const QString& folderPath);

    Q_INVOKABLE bool rename(const QString& oldPath, const QString& newPath);
    Q_INVOKABLE bool copy(const QString& sourcePath, const QString& destinationPath);
    Q_INVOKABLE QString copyToDirectory(const QString& sourcePath, const QString& directoryPath);
    Q_INVOKABLE QString moveToDirectory(const QString& sourcePath, const QString& directoryPath);
    Q_INVOKABLE bool remove_file(const QString& filePath);
    Q_INVOKABLE QStringList filesInDirectory(const QString& directoryPath);
    Q_INVOKABLE bool removeDirectory(const QString& directoryPath);
    Q_INVOKABLE QString clone(const QString& filePath);
    Q_INVOKABLE bool revealInFileManager(const QString& filePath);
    Q_INVOKABLE QString runtimePath();
    Q_INVOKABLE QUrl dialogFolderUrl(const QString& path);
    Q_INVOKABLE QVariantList backgroundImages();
    Q_INVOKABLE QString importBackgroundImage(const QString& sourcePath);
    Q_INVOKABLE bool removeBackgroundImage(const QString& sourceUrl);

private:
    static QString localPath(const QString& path);
    static QString availableFilePath(const QDir& directory, const QFileInfo& sourceInfo);
    static bool copyDirectory(const QString& sourcePath, const QString& destinationPath);
};
