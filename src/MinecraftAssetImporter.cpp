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
}

MinecraftAssetImporter::~MinecraftAssetImporter()
{
    if (m_cancel) m_cancel->store(true);
    if (m_catalogCancel) m_catalogCancel->store(true);
    m_watcher.waitForFinished();
    m_catalogWatcher.waitForFinished();
}

void MinecraftAssetImporter::refreshVersions(const QString &itemsRoot)
{
    if (loadingVersions()) return;
    m_catalogCancel = std::make_shared<std::atomic_bool>(false);
    const auto cancel = m_catalogCancel;
    m_versionsStatus = "正在读取 Mojang 官方版本列表…";
    m_catalogWatcher.setFuture(QtConcurrent::run([itemsRoot, cancel] {
        return MinecraftImport::fetchVersions(itemsRoot, cancel);
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
