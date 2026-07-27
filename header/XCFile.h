#include <QObject>
#include <QFile>
#include <QTextStream>
#include <QtQml>    // QML_ELEMENT macro
#include <QDir>


class XCFile : public QObject {
    Q_OBJECT
    QML_ELEMENT     //注册至qml

public:
    XCFile();
    Q_INVOKABLE bool write(const QString& filePath,const QString& content);
    Q_INVOKABLE QString read(const QString& filePath);
    Q_INVOKABLE bool exists(const QString& filePath);
    Q_INVOKABLE bool folder(const QString& folderPath);

    Q_INVOKABLE bool rename(const QString& oldPath, const QString& newPath);
    Q_INVOKABLE bool remove_file(const QString& filePath);
    Q_INVOKABLE bool remove_folder(const QString& folderPath);
    Q_INVOKABLE bool clone(const QString& filePath);
    Q_INVOKABLE QString appDataPath();

};
