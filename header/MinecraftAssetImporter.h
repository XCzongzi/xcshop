#pragma once

#include "MinecraftImportSupport.h"
#include <QObject>
#include <QFutureWatcher>
#include <QtQml>

class MinecraftAssetImporter : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    Q_PROPERTY(bool importing READ importing NOTIFY stateChanged)
    Q_PROPERTY(bool loadingVersions READ loadingVersions NOTIFY versionsChanged)
    Q_PROPERTY(QVariantList versions READ versions NOTIFY versionsChanged)
    Q_PROPERTY(QString versionsStatus READ versionsStatus NOTIFY versionsChanged)
    Q_PROPERTY(int progress READ progress NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap lastReport READ lastReport NOTIFY stateChanged)

    explicit MinecraftAssetImporter(QObject *parent = nullptr);
    ~MinecraftAssetImporter() override;
    bool importing() const { return m_importing; }
    bool loadingVersions() const { return m_catalogWatcher.isRunning(); }
    QVariantList versions() const { return m_versions; }
    QString versionsStatus() const { return m_versionsStatus; }
    int progress() const { return m_progress; }
    QString status() const { return m_status; }
    QVariantMap lastReport() const { return m_lastReport; }

    Q_INVOKABLE void refreshVersions(const QString &itemsRoot);
    Q_INVOKABLE bool startImport(const QVariantMap &options);
    Q_INVOKABLE void cancel();

signals:
    void stateChanged();
    void versionsChanged();
    void importFinished(const QVariantMap &report);

private:
    bool m_importing = false;
    int m_progress = 0;
    QString m_status;
    QString m_versionsStatus;
    QVariantList m_versions;
    QVariantMap m_lastReport;
    MinecraftImport::Cancellation m_cancel;
    MinecraftImport::Cancellation m_catalogCancel;
    QFutureWatcher<QVariantMap> m_watcher;
    QFutureWatcher<QVariantMap> m_catalogWatcher;
};
