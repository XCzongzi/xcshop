// 元素中转区的纯数据操作。
//
// 此文件不依赖 QML Item、Global 或 SignalBus，便于单独阅读和复用。
// 调用方负责：路径规范化、元素记录解析、持久化、以及界面模型刷新。

function createEmptyState() {
    return { "recent": [], "favorites": [], "groups": [] }
}

function clone(value) {
    try {
        return JSON.parse(JSON.stringify(value))
    } catch (error) {
        return null
    }
}

function normalizeState(value) {
    var result = value && typeof value === "object" ? clone(value) : null
    if (!result)
        result = createEmptyState()

    if (!Array.isArray(result.recent))
        result.recent = []
    if (!Array.isArray(result.favorites))
        result.favorites = []
    if (!Array.isArray(result.groups))
        result.groups = []

    for (var i = 0; i < result.groups.length; ++i) {
        if (!result.groups[i].id)
            result.groups[i].id = "group-" + i
        if (!result.groups[i].name)
            result.groups[i].name = "分组 " + (i + 1)
        if (!Array.isArray(result.groups[i].items))
            result.groups[i].items = []
    }
    return result
}

function canonicalType(value) {
    switch (String(value || "").toLowerCase()) {
    case "ui": return "UI"
    case "item": return "Item"
    case "cost": return "Cost"
    case "display": return "Display"
    default: return ""
    }
}

function typeLabel(value) {
    switch (canonicalType(value)) {
    case "UI": return "界面"
    case "Item": return "商品"
    case "Cost": return "代价"
    case "Display": return "展示"
    default: return "元素"
    }
}

function customGroupIndex(state, key) {
    if (key.indexOf("custom:") !== 0)
        return -1

    var id = key.substring(7)
    for (var i = 0; i < state.groups.length; ++i) {
        if (state.groups[i].id === id)
            return i
    }
    return -1
}

function itemsForGroup(state, key) {
    if (key === "recent")
        return state.recent
    if (key === "favorites")
        return state.favorites

    var index = customGroupIndex(state, key)
    return index >= 0 ? state.groups[index].items : []
}

function indexOfPath(items, path, normalizePath) {
    var normalizedTarget = normalizePath(path)
    for (var i = 0; i < items.length; ++i) {
        if (normalizePath(items[i].path) === normalizedTarget)
            return i
    }
    return -1
}

function removePath(items, path, normalizePath) {
    var normalizedTarget = normalizePath(path)
    var result = []
    for (var i = 0; i < items.length; ++i) {
        if (normalizePath(items[i].path) !== normalizedTarget)
            result.push(items[i])
    }
    return result
}

function addRecent(state, record, normalizePath) {
    var recent = removePath(state.recent, record.path, normalizePath)
    recent.unshift(record)
    state.recent = recent
}

function toggleFavorite(state, record, normalizePath) {
    var alreadyFavorite = indexOfPath(state.favorites, record.path, normalizePath) >= 0
    var favorites = removePath(state.favorites, record.path, normalizePath)
    if (!alreadyFavorite)
        favorites.unshift(clone(record))
    state.favorites = favorites
}

function addCustomGroup(state, name, id) {
    state.groups.push({ "id": id, "name": name, "items": [] })
}

function renameCustomGroup(state, key, name) {
    var index = customGroupIndex(state, key)
    if (index < 0)
        return false
    state.groups[index].name = name
    return true
}

function removeCustomGroup(state, key) {
    var index = customGroupIndex(state, key)
    if (index < 0)
        return false
    state.groups.splice(index, 1)
    return true
}

function reorderCustomGroup(state, sourceIndex, insertionIndex) {
    if (sourceIndex < 0 || sourceIndex >= state.groups.length
            || insertionIndex < 0 || insertionIndex > state.groups.length)
        return false

    var destinationIndex = insertionIndex
    if (sourceIndex < destinationIndex)
        destinationIndex -= 1
    if (sourceIndex === destinationIndex)
        return false

    var group = state.groups.splice(sourceIndex, 1)[0]
    state.groups.splice(destinationIndex, 0, group)
    return true
}

function moveRecordToGroup(state, sourceKey, record, targetKey, normalizePath) {
    if (targetKey === "recent") {
        addRecent(state, record, normalizePath)
        return
    }
    if (targetKey === "favorites") {
        if (indexOfPath(state.favorites, record.path, normalizePath) < 0)
            state.favorites.unshift(clone(record))
        return
    }

    var targetIndex = customGroupIndex(state, targetKey)
    if (targetIndex < 0)
        return

    var sourceIndex = customGroupIndex(state, sourceKey)
    if (sourceIndex >= 0 && sourceIndex !== targetIndex) {
        state.groups[sourceIndex].items = removePath(state.groups[sourceIndex].items,
                                                     record.path, normalizePath)
    }
    state.groups[targetIndex].items = removePath(state.groups[targetIndex].items,
                                                  record.path, normalizePath)
    state.groups[targetIndex].items.push(clone(record))
}

function reorderGroup(state, groupKey, record, targetIndex, normalizePath) {
    var items = itemsForGroup(state, groupKey)
    var sourceIndex = indexOfPath(items, record.path, normalizePath)
    if (sourceIndex < 0 || targetIndex < 0 || sourceIndex === targetIndex)
        return false

    var moved = items.splice(sourceIndex, 1)[0]
    if (sourceIndex < targetIndex)
        targetIndex -= 1
    items.splice(Math.max(0, Math.min(targetIndex, items.length)), 0, moved)

    if (groupKey === "recent")
        state.recent = items
    else if (groupKey === "favorites")
        state.favorites = items
    else {
        var groupIndex = customGroupIndex(state, groupKey)
        if (groupIndex >= 0)
            state.groups[groupIndex].items = items
    }
    return true
}

function removeRecordEverywhere(state, path, normalizePath) {
    var changed = indexOfPath(state.recent, path, normalizePath) >= 0
                  || indexOfPath(state.favorites, path, normalizePath) >= 0
    state.recent = removePath(state.recent, path, normalizePath)
    state.favorites = removePath(state.favorites, path, normalizePath)
    for (var i = 0; i < state.groups.length; ++i) {
        changed = indexOfPath(state.groups[i].items, path, normalizePath) >= 0 || changed
        state.groups[i].items = removePath(state.groups[i].items, path, normalizePath)
    }
    return changed
}

function replaceRecordEverywhere(state, oldPath, record, normalizePath) {
    var changed = false
    function replace(items) {
        for (var i = 0; i < items.length; ++i) {
            if (normalizePath(items[i].path) === normalizePath(oldPath)) {
                items[i] = clone(record)
                changed = true
            }
        }
    }

    replace(state.recent)
    replace(state.favorites)
    for (var i = 0; i < state.groups.length; ++i)
        replace(state.groups[i].items)
    return changed
}

function removeRecordFromGroup(state, groupKey, path, normalizePath) {
    if (groupKey === "recent")
        state.recent = removePath(state.recent, path, normalizePath)
    else if (groupKey === "favorites")
        state.favorites = removePath(state.favorites, path, normalizePath)
    else {
        var groupIndex = customGroupIndex(state, groupKey)
        if (groupIndex < 0)
            return false
        state.groups[groupIndex].items = removePath(state.groups[groupIndex].items,
                                                     path, normalizePath)
    }
    return true
}
