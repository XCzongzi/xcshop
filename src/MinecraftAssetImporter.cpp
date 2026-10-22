#include "MinecraftAssetImporter.h"
#include <QMetaObject>
#include <QtConcurrent/QtConcurrentRun>

MinecraftAssetImporter::MinecraftAssetImporter(QObject *parent) : QObject(parent)
{
    connect(&m_watcher, &QFutureWatcher<QVariantMap>::finished, this, [this] {
        m_lastReport = m_watcher.result();
        m_importing = false;
        m_status = m_lastReport.value("message").toString();
        m_progress = m_lastReport.value("ok").toBool() ? 100 : 0;
        emit stateChanged();
        emit importFinished(m_lastReport);
    });
    connect(&m_catalogWatcher, &QFutureWatcher<QVariantMap>::finished, this, [this] {
        const auto result = m_catalogWatcher.result();
        if (result.value("ok").toBool()) m_versions = result.value("versions").toList();
        m_versionsStatus = result.value("message").toString();
        emit versionsChanged();
    });
    connect(&m_localWatcher, &QFutureWatcher<QVariantMap>::finished, this, [this] {
        const auto result = m_localWatcher.result();
        if (result.value("sourcePath").toString() != m_localPath
            || (result.value("cancelled").toBool() && !m_localPath.isEmpty())) {
            inspectLocal(m_localPath);
            return;
        }
        m_localInfo = result;
        emit localInfoChanged();
    });
}

MinecraftAssetImporter::~MinecraftAssetImporter()
{
    if (m_cancel) m_cancel->store(true);
    if (m_catalogCancel) m_catalogCancel->store(true);
    if (m_localCancel) m_localCancel->store(true);
    m_watcher.waitForFinished();
    m_catalogWatcher.waitForFinished();
    m_localWatcher.waitForFinished();
}

void MinecraftAssetImporter::inspectLocal(const QString &sourcePath)
{
    m_localPath = sourcePath.trimmed();
    if (m_localWatcher.isRunning()) {
        if (m_localCancel) m_localCancel->store(true);
        return;
    }
    m_localInfo.clear();
    if (m_localPath.isEmpty()) { emit localInfoChanged(); return; }
    const auto path = m_localPath;
    m_localCancel = std::make_shared<std::atomic_bool>(false);
    const auto cancel = m_localCancel;
    m_localWatcher.setFuture(QtConcurrent::run([path, cancel] {
        return MinecraftImport::inspectLocalInstallation(path, cancel);
    }));
    emit localInfoChanged();
}

void MinecraftAssetImporter::refreshVersions(const QString &itemsRoot, bool allowNetwork)
{
    if (loadingVersions()) return;
    m_catalogCancel = std::make_shared<std::atomic_bool>(false);
    const auto cancel = m_catalogCancel;
    m_versionsStatus = allowNetwork ? "正在读取 Mojang 官方版本列表…" : "正在读取缓存的版本列表…";
    m_catalogWatcher.setFuture(QtConcurrent::run([itemsRoot, cancel, allowNetwork] {
        return MinecraftImport::fetchVersions(itemsRoot, cancel, allowNetwork);
    }));
    emit versionsChanged();
}

bool MinecraftAssetImporter::startImport(const QVariantMap &options)
{
    if (m_importing) return false;
    m_cancel = std::make_shared<std::atomic_bool>(false);
    const auto cancel = m_cancel;
    m_importing = true;
    m_progress = 0;
    m_status = "正在准备官方游戏数据…";
    m_lastReport.clear();
    emit stateChanged();
    m_watcher.setFuture(QtConcurrent::run([this, options, cancel] {
        return MinecraftImport::importGame(options, cancel, [this, cancel](int value, const QString &status) {
            if (cancel->load()) return;
            QMetaObject::invokeMethod(this, [this, cancel, value, status] {
                if (!m_importing || m_cancel != cancel) return;
                m_progress = value;
                m_status = status;
                emit stateChanged();
            }, Qt::QueuedConnection);
        });
    }));
    return true;
}

void MinecraftAssetImporter::cancel()
{
    if (!m_importing || !m_cancel) return;
    m_cancel->store(true);
    m_status = "正在取消导入…";
    emit stateChanged();
}
