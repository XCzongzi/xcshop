#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QUrl>

class QNetworkReply;

// Checks public, stable editor releases. Never downloads or installs software.
class UpdateChecker : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY releaseChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY releaseChanged)
    Q_PROPERTY(QString releaseNotes READ releaseNotes NOTIFY releaseChanged)
    Q_PROPERTY(QUrl releaseUrl READ releaseUrl NOTIFY releaseChanged)
public:
    explicit UpdateChecker(QObject *parent = nullptr);
    UpdateChecker(const QUrl &feedUrl, const QString &settingsPath,
                  int timeoutMs = 10000, QObject *parent = nullptr);
    bool checking() const { return m_checking; }
    bool updateAvailable() const { return !m_latestVersion.isEmpty(); }
    QString latestVersion() const { return m_latestVersion; }
    QString releaseNotes() const { return m_releaseNotes; }
    QUrl releaseUrl() const { return m_releaseUrl; }
    Q_INVOKABLE void check();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void dismissVersion(const QString &version);
signals:
    void checkingChanged();
    void releaseChanged();
    void startupUpdateAvailable();
    void checkFinished();
private:
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    QUrl m_feedUrl, m_releaseUrl;
    QString m_settingsPath, m_dismissedVersion, m_latestVersion, m_releaseNotes;
    int m_timeoutMs;
    bool m_checking = false;
};
