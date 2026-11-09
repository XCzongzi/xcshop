#include "MinecraftVersionCatalog.h"
#include "MinecraftDataPackVersions.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QSaveFile>
#include <QSettings>
#include <QTimer>

namespace {
constexpr qint64 dayMs = 24 * 60 * 60 * 1000;
constexpr qint64 maxResponseBytes = 4 * 1024 * 1024;
const auto successKey = QStringLiteral("versions/lastSuccessfulCheckMs");
}

MinecraftVersionCatalog::MinecraftVersionCatalog(QObject *parent)
    : MinecraftVersionCatalog(QCoreApplication::applicationDirPath() + "/minecraft-data-pack-versions.json",
                              QCoreApplication::applicationDirPath() + "/minecraft-version-state.ini",
                              QUrl("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"),
                              QUrl("https://xczongzi.net/projects/xcshop/downloads/minecraft-data-pack-versions.json"),
                              10000, parent) {}

MinecraftVersionCatalog::MinecraftVersionCatalog(const QString &localPath, const QString &statePath,
                                               const QUrl &manifestUrl, const QUrl &downloadUrl,
                                               int timeoutMs, QObject *parent)
    : QObject(parent), m_localPath(localPath), m_statePath(statePath),
      m_manifestUrl(manifestUrl), m_downloadUrl(downloadUrl), m_timeoutMs(timeoutMs) {
    reload();
}

void MinecraftVersionCatalog::reload() {
    const auto catalog = MinecraftDataPackVersions::load(m_localPath);
    m_versions = catalog.versions;
    emit versionsChanged();
}

void MinecraftVersionCatalog::checkForUpdates() {
    if (m_checking) return;
    reload();
    QSettings state(m_statePath, QSettings::IniFormat);
    const auto lastSuccess = state.value(successKey, 0).toLongLong();
    const auto elapsed = QDateTime::currentMSecsSinceEpoch() - lastSuccess;
    if (lastSuccess > 0 && elapsed >= 0 && elapsed < dayMs) return;
    m_checking = true;
    request(false);
}

void MinecraftVersionCatalog::request(bool mapping) {
    QNetworkRequest networkRequest(mapping ? m_downloadUrl : m_manifestUrl);
    networkRequest.setRawHeader("User-Agent", "xcshop-minecraft-versions/" + QCoreApplication::applicationVersion().toUtf8());
    networkRequest.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    networkRequest.setTransferTimeout(m_timeoutMs);
    auto *reply = m_network.get(networkRequest);
    reply->setReadBufferSize(maxResponseBytes + 1);
    QTimer::singleShot(m_timeoutMs, reply, [reply] { reply->abort(); });
    connect(reply, &QNetworkReply::readyRead, reply, [reply] {
        if (reply->bytesAvailable() > maxResponseBytes) reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, mapping] {
        const bool ok = reply->error() == QNetworkReply::NoError
            && reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 200
            && reply->bytesAvailable() <= maxResponseBytes;
        const auto bytes = ok ? reply->readAll() : QByteArray();
        reply->deleteLater();
        if (!ok) { finish(false); return; }
        if (!mapping) {
            QJsonParseError error;
            const auto document = QJsonDocument::fromJson(bytes, &error);
            const auto manifest = document.object();
            m_latestRelease = manifest.value("latest").toObject().value("release").toString();
            bool found = false;
            for (const auto &value : manifest.value("versions").toArray()) {
                const auto entry = value.toObject();
                if (entry.value("id").toString() == m_latestRelease && entry.value("type") == "release") found = true;
            }
            if (error.error != QJsonParseError::NoError || !document.isObject() || m_latestRelease.isEmpty() || !found) {
                finish(false);
                return;
            }
            const auto local = MinecraftDataPackVersions::load(m_localPath);
            if (local.valid() && local.versions.last() == m_latestRelease) {
                reload();
                finish(true);
                return;
            }
            request(true);
            return;
        }
        const auto catalog = MinecraftDataPackVersions::parse(bytes);
        if (!catalog.valid() || catalog.versions.last() != m_latestRelease) {
            finish(false);
            return;
        }
        QSaveFile file(m_localPath);
        if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size() || !file.commit()) {
            finish(false);
            return;
        }
        reload();
        finish(true);
    });
}

void MinecraftVersionCatalog::finish(bool success) {
    if (success) {
        QSettings state(m_statePath, QSettings::IniFormat);
        state.setValue(successKey, QDateTime::currentMSecsSinceEpoch());
        state.sync();
        success = state.status() == QSettings::NoError;
    }
    m_checking = false;
    emit checkFinished(success);
}
