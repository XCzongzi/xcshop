#pragma once

#include <QObject>
#include <QFutureWatcher>
#include <QVariantMap>
#include <QtQml>

class MinecraftAssetImporter : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    Q_PROPERTY(bool importing READ importing NOTIFY importingChanged)

    bool importing() const;
    Q_INVOKABLE void startImportGameJar(const QString &jarPath, const QString &itemsRootPath);

signals:
    void importingChanged();
    void progressChanged(int value, const QString &status);
    void importFinished(const QVariantMap &report);

private:
    bool m_importing = false;
    QFutureWatcher<QVariantMap> *m_watcher = nullptr;
};
