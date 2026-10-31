#include "UpdateChecker.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QSettings>
#include <QTimer>
#include <QVersionNumber>

namespace {
constexpr qint64 maxResponseBytes = 512 * 1024;

QVersionNumber stableVersion(const QString &text) {
    // Restrict the feed to numeric stable versions; fromString alone accepts suffixes.
    static const QRegularExpression format(QStringLiteral("^v?(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$"));
    if (!format.match(text).hasMatch()) return {};
    const auto numeric = text.startsWith('v') ? text.mid(1) : text;
    qsizetype end = 0;
    const auto version = QVersionNumber::fromString(numeric, &end);
    return end == numeric.size() ? version : QVersionNumber();
}

bool officialReleaseUrl(const QUrl &url) {
    return url.isValid() && url.scheme() == QStringLiteral("https")
        && url.host() == QStringLiteral("github.com") && url.userInfo().isEmpty()
        && url.port(-1) == -1 && url.query().isEmpty() && url.fragment().isEmpty()
        && url.path().startsWith(QStringLiteral("/XCzongzi/xcshop/releases/tag/"))
        && url.path().size() > QStringLiteral("/XCzongzi/xcshop/releases/tag/").size();
}
}

UpdateChecker::UpdateChecker(QObject *parent)
    : UpdateChecker(QUrl(QStringLiteral("https://api.github.com/repos/XCzongzi/xcshop/releases/latest")),
                    QCoreApplication::applicationDirPath() + QStringLiteral("/update-state.ini"),
                    10000, parent) {}

UpdateChecker::UpdateChecker(const QUrl &feedUrl, const QString &settingsPath,
                             int timeoutMs, QObject *parent)
    : QObject(parent), m_feedUrl(feedUrl), m_settingsPath(settingsPath), m_timeoutMs(timeoutMs) {
    QSettings settings(m_settingsPath, QSettings::IniFormat);
    m_dismissedVersion = settings.value(QStringLiteral("updates/dismissedVersion")).toString();
}

void UpdateChecker::check() {
    if (m_checking) return;
    m_checking = true;
    emit checkingChanged();
    QNetworkRequest request(m_feedUrl);
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("User-Agent", "xcshop-update-checker/" + QCoreApplication::applicationVersion().toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(m_timeoutMs);
    auto *reply = m_network.get(request);
    reply->setReadBufferSize(maxResponseBytes + 1);
    // Also bound the total request time, including slow trickling responses.
    QTimer::singleShot(m_timeoutMs, reply, [reply] { reply->abort(); });
    connect(reply, &QNetworkReply::readyRead, reply, [reply] {
        if (reply->bytesAvailable() > maxResponseBytes) reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const bool ok = reply->error() == QNetworkReply::NoError
            && reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 200
            && reply->bytesAvailable() <= maxResponseBytes;
        const QByteArray bytes = ok ? reply->readAll() : QByteArray();
        reply->deleteLater();
        m_checking = false;
        emit checkingChanged();

        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(bytes, &error);
        if (!ok || error.error != QJsonParseError::NoError || !document.isObject()) {
            emit checkFinished(); // Offline, rate-limited, or no public release yet: stay quiet.
            return;
        }
        const auto release = document.object();
        const auto latest = stableVersion(release.value("tag_name").toString());
        const auto current = stableVersion(QCoreApplication::applicationVersion());
        const QUrl url(release.value("html_url").toString());
        if (!release.value("draft").isBool() || release.value("draft").toBool()
            || !release.value("prerelease").isBool() || release.value("prerelease").toBool()
            || latest.isNull() || current.isNull() || !officialReleaseUrl(url)) {
            emit checkFinished();
            return;
        }

        m_latestVersion = latest > current ? latest.toString() : QString();
        m_releaseNotes = updateAvailable() ? release.value("body").toString().left(12000) : QString();
        m_releaseUrl = updateAvailable() ? url : QUrl();
        emit releaseChanged();
        if (updateAvailable() && m_latestVersion != m_dismissedVersion)
            emit startupUpdateAvailable();
        emit checkFinished();
    });
}

void UpdateChecker::dismissVersion(const QString &version) {
    if (version.isEmpty() || version != m_latestVersion) return;
    m_dismissedVersion = version;
    QSettings settings(m_settingsPath, QSettings::IniFormat);
    settings.setValue(QStringLiteral("updates/dismissedVersion"), version);
    settings.sync();
    if (settings.status() != QSettings::NoError)
        qWarning("Could not save dismissed update version to update-state.ini");
}
