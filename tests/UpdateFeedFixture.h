#pragma once

#include <QJsonDocument>
#include <QJsonObject>
#include <QTcpServer>
#include <QTcpSocket>

// Only compiled into tests. Never contacts GitHub or uses personal settings.
class UpdateFeedFixture : public QObject {
    Q_OBJECT
public:
    QTcpServer server;
    QByteArray body;
    int status = 200;
    int requests = 0;
    bool stall = false;
    explicit UpdateFeedFixture(QObject *parent = nullptr) : QObject(parent) {
        server.listen(QHostAddress::LocalHost);
        setVersion(QStringLiteral("0.2.0"));
        connect(&server, &QTcpServer::newConnection, this, [this] {
            while (auto *socket = server.nextPendingConnection()) {
                socket->setParent(this);
                connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
                connect(socket, &QTcpSocket::readyRead, socket, [this, socket] {
                    auto request = socket->property("request").toByteArray() + socket->readAll();
                    socket->setProperty("request", request);
                    if (!request.contains("\r\n\r\n") || socket->property("answered").toBool()) return;
                    socket->setProperty("answered", true);
                    ++requests;
                    if (stall) return;
                    socket->write("HTTP/1.1 " + QByteArray::number(status) + " Test\r\nContent-Type: application/json\r\nContent-Length: "
                                  + QByteArray::number(body.size()) + "\r\nConnection: close\r\n\r\n" + body);
                    socket->disconnectFromHost();
                });
            }
        });
    }
    QUrl url() const { return QUrl(QStringLiteral("http://127.0.0.1:%1/latest").arg(server.serverPort())); }
    Q_INVOKABLE void setVersion(const QString &version) {
        status = 200;
        setRelease(QJsonObject{{"tag_name", "v" + version}, {"draft", false}, {"prerelease", false},
            {"body", QStringLiteral("修复已知问题，改善编辑体验。")},
            {"html_url", "https://github.com/XCzongzi/xcshop/releases/tag/v" + version}});
    }
    Q_INVOKABLE void recordOpenedUrl(const QUrl &url) { m_openedUrls.append(url); }
    Q_INVOKABLE int openedCount() const { return m_openedUrls.size(); }
    Q_INVOKABLE QString lastOpenedUrl() const { return m_openedUrls.isEmpty() ? QString() : m_openedUrls.last().toString(); }
    void setRelease(const QJsonObject &release) { body = QJsonDocument(release).toJson(); }
private:
    QList<QUrl> m_openedUrls;
};
