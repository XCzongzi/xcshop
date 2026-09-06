#include "ContainerCatalog.h"

#include <array>

namespace {
enum class ContainerKind {
    Block,
    Entity
};

struct ContainerDefinition {
    const char *id;
    const char *label;
    int interfaceId;
    ContainerKind kind;
    bool largeChest;
};

// interfaceId is the matching file in assets/minecraft/gui/container.
// Variants with the same vanilla inventory screen intentionally share an ID.
constexpr std::array<ContainerDefinition, 17> containers{{
    {"barrel", "木桶（27 格）", 0, ContainerKind::Block, false},
    {"chest", "箱子（27 格）", 0, ContainerKind::Block, false},
    {"trapped_chest", "陷阱箱（27 格）", 0, ContainerKind::Block, false},
    {"ender_chest", "末影箱（27 格）", 0, ContainerKind::Block, false},
    {"shulker_box", "潜影盒（27 格）", 0, ContainerKind::Block, false},
    {"dispenser", "发射器（9 格）", 2, ContainerKind::Block, false},
    {"dropper", "投掷器（9 格）", 2, ContainerKind::Block, false},
    {"hopper", "漏斗（5 格）", 3, ContainerKind::Block, false},
    {"brewing_stand", "酿造台（5 格）", 4, ContainerKind::Block, false},
    {"furnace", "熔炉（3 格）", 5, ContainerKind::Block, false},
    {"blast_furnace", "高炉（3 格）", 5, ContainerKind::Block, false},
    {"smoker", "烟熏炉（3 格）", 5, ContainerKind::Block, false},
    {"large_chest", "大型箱子（54 格）", 1, ContainerKind::Block, true},
    {"large_trapped_chest", "大型陷阱箱（54 格）", 1, ContainerKind::Block, true},
    {"chest_minecart", "运输矿车（箱子，27 格）", 0, ContainerKind::Entity, false},
    {"chest_boat", "运输船／筏（箱子，27 格）", 0, ContainerKind::Entity, false},
    {"hopper_minecart", "漏斗矿车（5 格）", 3, ContainerKind::Entity, false}
}};

QVariantMap optionFor(const ContainerDefinition &container)
{
    return {
        {QStringLiteral("id"), QString::fromLatin1(container.id)},
        {QStringLiteral("label"), QString::fromUtf8(container.label)},
        {QStringLiteral("interfaceId"), container.interfaceId}
    };
}
}

QVariantList ContainerCatalog::blockContainers(bool includeLargeChests) const
{
    QVariantList result;
    result.reserve(static_cast<qsizetype>(containers.size()));
    for (const auto &container : containers) {
        if (container.kind == ContainerKind::Block
                && (includeLargeChests || !container.largeChest))
            result.append(optionFor(container));
    }
    return result;
}

QVariantList ContainerCatalog::entityContainers(bool includeEntities) const
{
    QVariantList result;
    if (!includeEntities)
        return result;

    result.reserve(static_cast<qsizetype>(containers.size()));
    for (const auto &container : containers) {
        if (container.kind == ContainerKind::Entity)
            result.append(optionFor(container));
    }
    return result;
}

int ContainerCatalog::interfaceForContainer(const QString &containerId) const
{
    for (const auto &container : containers) {
        if (containerId == QLatin1String(container.id))
            return container.interfaceId;
    }
    return -1;
}
