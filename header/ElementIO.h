#include <QObject>
#include <QFile>
#include <QTextStream>
#include <QtQml>    // QML_ELEMENT macro
#include <QDir>


class ElementIO : public QObject {
    Q_OBJECT
    QML_ELEMENT     //注册至qml

public:
    ElementIO();
    ~ElementIO();
    Q_INVOKABLE bool open(const QString& filePath);
    Q_INVOKABLE void close(const QString& filePath);
    Q_INVOKABLE void write(const QString& filePath);
    Q_INVOKABLE QString read();

};