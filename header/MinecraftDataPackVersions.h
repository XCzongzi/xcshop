#pragma once

#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QVariantMap>

namespace MinecraftDataPackVersions {
struct Catalog {
    QStringList versions; // Numeric game ordering, oldest first.
    QJsonObject entries;
    QString error;
    bool valid() const { return error.isEmpty() && !versions.isEmpty(); }
};
Catalog parse(const QByteArray &bytes);
Catalog load(const QString &path);
// Reads the editable local mapping. Only releases newer than its newest entry
// may fall back; an unknown historical version is an error.
QVariantMap resolve(const QString &path, const QString &version);
}
