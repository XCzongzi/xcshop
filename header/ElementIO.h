#include <QObject>
#include <QString>
#include <QtQml>    // QML_ELEMENT macro


class ElementIO : public QObject {
    Q_OBJECT
    QML_ELEMENT     //注册至qml

public:
    ElementIO();
    Q_INVOKABLE bool open(const QString& filePath);
    Q_INVOKABLE void close();
    Q_INVOKABLE bool write(const QString& content);
    Q_INVOKABLE QString read();

private:
    QString m_filePath;
};
