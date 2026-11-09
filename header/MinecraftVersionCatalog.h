#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QStringList>
#include <QUrl>

// Project version choices always come from the local data-pack mapping.
class MinecraftVersionCatalog : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList versions READ versions NOTIFY versionsChanged)
public:
    explicit MinecraftVersionCatalog(QObject *parent = nullptr);
    MinecraftVersionCatalog(const QString &localPath, const QString &statePath,
                            const QUrl &manifestUrl, const QUrl &downloadUrl,
                            int timeoutMs = 10000, QObject *parent = nullptr);
    QStringList versions() const { return m_versions; }
    bool checking() const { return m_checking; }
    Q_INVOKABLE void reload();
    Q_INVOKABLE void checkForUpdates();
signals:
    void versionsChanged();
    void checkFinished(bool success);
private:
    void request(bool mapping);
    void finish(bool success);
    QNetworkAccessManager m_network;
    QString m_localPath, m_statePath, m_latestRelease;
    QUrl m_manifestUrl, m_downloadUrl;
    QStringList m_versions;
    int m_timeoutMs;
    bool m_checking = false;
};
