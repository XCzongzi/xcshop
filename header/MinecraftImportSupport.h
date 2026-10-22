#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <atomic>
#include <functional>
#include <memory>

namespace MinecraftImport {
using Cancellation = std::shared_ptr<std::atomic_bool>;
using Progress = std::function<void(int, const QString &)>;
inline constexpr int CatalogSchema = 2;
inline constexpr int RendererVersion = 2;

// Registry reports changed shape over time. Display resources are not a registry.
QJsonArray parseItemReports(const QJsonObject &registries, const QJsonObject &items,
                           QString *error = nullptr);
QVariantList parseVersions(const QJsonObject &manifest);
bool validItemId(const QString &id);
QString localPath(const QString &path);
QVariantMap fetchVersions(const QString &itemsRoot, const Cancellation &cancel);
QVariantMap importGame(const QVariantMap &options, const Cancellation &cancel,
                       const Progress &progress);

struct IconResult {
    QString status; // rendered, approximate, missing, empty
    QString reason;
};
IconResult renderItem(const QString &assetsRoot, const QString &id,
                      const QJsonObject &components, const QString &outputPath);

// Completed packs are immutable; activation changes only a small atomic pointer.
bool activatePack(const QString &itemsRoot, const QString &relativePack, QString *error);
QString activePack(const QString &itemsRoot);
} // namespace MinecraftImport
