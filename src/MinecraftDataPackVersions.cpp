#include "MinecraftDataPackVersions.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QRegularExpression>
#include <array>
#include <cmath>
#include <limits>
#include <optional>
#include <algorithm>

namespace {
using Release = std::array<int, 3>;
std::optional<Release> releaseKey(const QString &version) {
    static const QRegularExpression pattern(QStringLiteral("^(1|[2-9][0-9])\\.([0-9]+)(?:\\.([0-9]+))?$"));
    const auto match = pattern.match(version);
    if (!match.hasMatch()) return {};
    Release result{0, 0, 0};
    for (int i = 0; i < 3; ++i) {
        const auto text = match.captured(i + 1);
        if (text.isEmpty()) continue;
        bool ok = false;
        result[i] = text.toInt(&ok);
        if (!ok || (text.size() > 1 && text.startsWith('0'))) return {};
    }
    if (result < Release{1, 13, 0} || (result[0] != 1 && (result[0] < 26 || result[1] < 1))) return {};
    return result;
}

bool integer(const QJsonValue &value, int minimum) {
    if (!value.isDouble()) return false;
    const auto number = value.toDouble();
    return std::isfinite(number) && number >= minimum
        && number <= std::numeric_limits<int>::max() && number == std::floor(number);
}
}

MinecraftDataPackVersions::Catalog MinecraftDataPackVersions::parse(const QByteArray &bytes) {
    const auto failure = [](const QString &message) { return Catalog{{}, {}, message}; };
    QJsonParseError error;
    const auto document = QJsonDocument::fromJson(bytes, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject())
        return failure("数据包版本映射表不是有效 JSON 对象。");
    const auto root = document.object();
    if (root["schemaVersion"] != QJsonValue(1) || !root["versions"].isObject() || root["versions"].toObject().isEmpty())
        return failure("数据包版本映射表须包含 schemaVersion: 1 和非空 versions 对象。");
    const auto versions = root["versions"].toObject();
    QStringList ids;
    for (auto it = versions.begin(); it != versions.end(); ++it) {
        const auto key = releaseKey(it.key());
        const auto pack = it.value().toObject();
        if (!key || !it.value().isObject() || !integer(pack["major"], 1) || !integer(pack["minor"], 0))
            return failure("数据包版本映射项无效（需要正式版 ID 和整数 major/minor）：" + it.key());
        ids.append(it.key());
    }
    std::sort(ids.begin(), ids.end(), [](const QString &a, const QString &b) { return *releaseKey(a) < *releaseKey(b); });
    return {ids, versions, {}};
}

MinecraftDataPackVersions::Catalog MinecraftDataPackVersions::load(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {{}, {}, "无法读取数据包版本映射表：" + path};
    return parse(file.readAll());
}

QVariantMap MinecraftDataPackVersions::resolve(const QString &path, const QString &version) {
    const auto failure = [](const QString &message) {
        return QVariantMap{{"valid", false}, {"error", message}};
    };
    const auto requested = releaseKey(version);
    if (!requested) return failure("数据包版本映射只支持 1.13 起的正式版游戏 ID：" + version);
    const auto catalog = load(path);
    if (!catalog.valid()) return failure(catalog.error);
    const auto versions = catalog.entries;
    const auto newestId = catalog.versions.last();
    const auto newest = *releaseKey(newestId);
    const bool exact = versions.contains(version);
    if (!exact && *requested <= newest)
        return failure("数据包版本映射表缺少游戏版本 " + version + "，请补充 minecraft-data-pack-versions.json。");
    const auto source = exact ? version : newestId;
    const auto pack = versions[source].toObject();
    return {{"valid", true}, {"major", pack["major"].toInt()}, {"minor", pack["minor"].toInt()},
            {"sourceVersion", source}, {"fallback", !exact}};
}
