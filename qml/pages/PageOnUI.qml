pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop
import Qt5Compat.GraphicalEffects

BaseIOPage {
    id: root
    color: Colors.transparent
    workspace: true

    // This is the resource/interface number (0-5).
    property int containerType: -1
    property string customName: ""
    property string openCommand: ""
    property bool changingContainerType: false
    property bool pageInitialized: false
    property int currentSlotIndex: -1
    property int previewRevision: 0
    property var previewOffers: ({})
    property int layoutRevision: 0
    property string selectedNestedGroupId: ""
    property bool nestingDrawMode: false
    property var workspaceUndoHistory: []
    property var workspaceRedoHistory: []
    property bool replayingWorkspaceEdit: false
    readonly property bool canUndoWorkspace: workspaceUndoHistory.length > 0
    readonly property bool canRedoWorkspace: workspaceRedoHistory.length > 0
    readonly property bool textEditorFocused: {
        var item = root.Window.window ? root.Window.window.activeFocusItem : null
        return item instanceof TextInput || item instanceof TextEdit
    }
    readonly property bool containerConfigured: containerType >= 0
    readonly property bool editorReady: dataLoaded && containerConfigured
                                      && !changingContainerType
    readonly property int currentSlotCount: containerType >= 0
                                            && containerType < Constants.containerCount.length
                                            ? Constants.containerCount[containerType] : 0
    readonly property string currentContainerTypeLabel: {
        return containerType >= 0 && containerType < containerTypeOptions.length
                ? containerTypeOptions[containerType].label : "未选择"
    }
    readonly property var layoutKinds: [
        "generic_9x3", "generic_9x6", "generic_3x3",
        "hopper_5", "brewing_stand_5", "furnace_3"
    ]
    readonly property var containerTypeOptions: [
        { "type": "generic_9x3", "label": "普通容器界面（27 格）" },
        { "type": "generic_9x6", "label": "大型容器界面（54 格）" },
        { "type": "generic_3x3", "label": "3 × 3 容器界面（9 格）" },
        { "type": "hopper_5", "label": "漏斗界面（5 格）" },
        { "type": "brewing_stand_5", "label": "酿造台界面（5 格）" },
        { "type": "furnace_3", "label": "熔炉界面（3 格）" }
    ]

    signal slotItemsChanged(int slotIndex)
    signal layoutDataChanged()

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: root.visible && root.enabled && root.nestingDrawMode
        autoRepeat: false
        onActivated: root.setNestingDrawMode(false)
    }
    Shortcut {
        sequence: "Ctrl+Z"
        enabled: root.visible && root.enabled && root.editorReady && !root.textEditorFocused
        onActivated: root.undoWorkspaceEdit()
    }
    Shortcut {
        sequence: "Ctrl+Shift+Z"
        enabled: root.visible && root.enabled && root.editorReady && !root.textEditorFocused
        onActivated: root.redoWorkspaceEdit()
    }

    // Text editors consume Delete first; unhandled keys bubble up from the canvas.
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Delete && event.modifiers === Qt.NoModifier
                && root.editorReady && root.currentSlotIndex >= 0) {
            root.clearSlotItems(root.currentSlotIndex)
            event.accepted = true
        }
    }

    function clearWorkspaceHistory() {
        root.workspaceUndoHistory = []
        root.workspaceRedoHistory = []
    }

    function captureWorkspaceEdit(indices, includeGroups, membershipGroup) {
        var slots = []
        for (var index of indices) {
            var record = root.slotRecord(index, false)
            var items = record ? record.items.slice() : []
            slots.push({ "index": index, "exists": !!record, "items": items,
                         "elements": items.map(function(item) { return item.element }),
                         "preview": items[root.previewItemIndex(index)] || null })
        }
        // Keep item identities, so later property edits survive structural undo/redo.
        return {
            "slots": slots,
            "groups": includeGroups ? root.nestedGroups().slice() : null,
            "membership": membershipGroup
                          ? { "group": membershipGroup, "slots": membershipGroup.slots.slice() } : null,
            "currentSlot": root.currentSlotIndex,
            "selectedGroup": root.selectedNestedGroupId,
            "drawing": root.nestingDrawMode,
            "editor": inspector.selectedEditor
        }
    }

    function workspaceEditKey(state) {
        return JSON.stringify({
            "slots": state.slots.map(function(slot) {
                return { "index": slot.index, "exists": slot.exists, "items": slot.items,
                         "preview": slot.items.indexOf(slot.preview) }
            }),
            "groups": state.groups ? state.groups.map(function(group) { return group.id }) : null,
            "membership": state.membership ? state.membership.slots : null
        })
    }

    function beginWorkspaceEdit(indices, includeGroups, membershipGroup) {
        inspector.finishEditing()
        var before = root.captureWorkspaceEdit(indices, includeGroups, membershipGroup)
        return { "indices": indices, "includeGroups": includeGroups === true,
                 "membershipGroup": membershipGroup || null, "before": before,
                 "beforeKey": root.workspaceEditKey(before) }
    }

    function finishWorkspaceEdit(edit) {
        if (root.replayingWorkspaceEdit)
            return
        edit.after = root.captureWorkspaceEdit(edit.indices, edit.includeGroups, edit.membershipGroup)
        if (edit.beforeKey === root.workspaceEditKey(edit.after))
            return
        root.workspaceUndoHistory = root.workspaceUndoHistory.concat([edit]).slice(-200)
        root.workspaceRedoHistory = []
    }

    function applyWorkspaceEdit(state) {
        var indices = state.slots.map(function(slot) { return slot.index })
        root.eledata.slots = root.eledata.slots.filter(function(slot) {
            return indices.indexOf(Number(slot.index)) < 0
        })
        var previews = Object.assign({}, root.previewOffers)
        for (var slot of state.slots) {
            delete previews[String(slot.index)]
            if (slot.exists) {
                for (var itemIndex = 0; itemIndex < slot.items.length; ++itemIndex)
                    slot.items[itemIndex].element = slot.elements[itemIndex]
                root.eledata.slots.push({ "index": slot.index, "items": slot.items.slice() })
                var preview = slot.items.indexOf(slot.preview)
                if (preview >= 0)
                    previews[String(slot.index)] = preview
            }
        }
        root.eledata.slots.sort(function(first, second) { return first.index - second.index })
        root.previewOffers = previews
        if (state.groups)
            root.eledata.nestedGroups = state.groups.slice()
        if (state.membership && root.nestedGroups().indexOf(state.membership.group) >= 0)
            state.membership.group.slots = state.membership.slots.slice()
        root.currentSlotIndex = state.currentSlot
        root.selectedNestedGroupId = root.nestedGroupIndex(state.selectedGroup) >= 0 ? state.selectedGroup : ""
        root.nestingDrawMode = state.drawing && root.selectedNestedGroupId.length > 0
        inspector.restoreEditor(state.editor)
    }

    function replayWorkspaceEdit(redo) {
        var history = redo ? root.workspaceRedoHistory : root.workspaceUndoHistory
        if (!root.editorReady || root.replayingWorkspaceEdit || !history.length)
            return false
        inspector.finishEditing()
        root.forceActiveFocus()
        var edit = history[history.length - 1]
        var rollback = root.captureWorkspaceEdit(edit.indices, edit.includeGroups, edit.membershipGroup)
        root.replayingWorkspaceEdit = true
        var saved = false
        try {
            root.applyWorkspaceEdit(redo ? edit.after : edit.before)
            saved = root.updateDataOut()
            if (!saved)
                root.applyWorkspaceEdit(rollback)
            else if (redo) {
                root.workspaceRedoHistory = history.slice(0, -1)
                root.workspaceUndoHistory = root.workspaceUndoHistory.concat([edit])
            } else {
                root.workspaceUndoHistory = history.slice(0, -1)
                root.workspaceRedoHistory = root.workspaceRedoHistory.concat([edit])
            }
            root.notifyLayoutLoaded()
            for (var index of edit.indices)
                root.notifySlotChanged(index)
        } finally {
            root.replayingWorkspaceEdit = false
        }
        return saved
    }

    function undoWorkspaceEdit() { return root.replayWorkspaceEdit(false) }
    function redoWorkspaceEdit() { return root.replayWorkspaceEdit(true) }

    function defaultSaleItem() {
        return {
            "element": "",
            "filter": { "scoreboard": "", "target": "", "score": "" },
            "macros": []
        }
    }

    function normalizeSaleItem(value) {
        var source = value && typeof value === "object" && !Array.isArray(value)
                ? value : ({})
        var filter = source.filter && typeof source.filter === "object"
                && !Array.isArray(source.filter) ? source.filter : ({})
        var sourceMacros = Array.isArray(source.macros) ? source.macros : []
        var macros = []
        for (var macroIndex = 0; macroIndex < sourceMacros.length; ++macroIndex) {
            var macro = sourceMacros[macroIndex]
            if (!macro || typeof macro !== "object" || Array.isArray(macro))
                continue
            macros.push({
                "name": typeof macro.name === "string" ? macro.name : "",
                "value": typeof macro.value === "string" ? macro.value : ""
            })
        }
        return {
            "element": typeof source.element === "string" ? source.element : "",
            "filter": {
                "scoreboard": typeof filter.scoreboard === "string" ? filter.scoreboard : "",
                "target": typeof filter.target === "string" ? filter.target : "",
                "score": typeof filter.score === "string" ? filter.score : ""
            },
            "macros": macros
        }
    }

    function saleItemHasData(item) {
        if (!item)
            return false
        if (typeof item.element === "string" && item.element.length)
            return true
        var filter = item.filter || ({})
        if (String(filter.scoreboard || "").length
                || String(filter.target || "").length
                || String(filter.score || "").length)
            return true
        return Array.isArray(item.macros) && item.macros.length > 0
    }

    function storageData() {
        var stored = JSON.parse(JSON.stringify(root.eledata))
        var slots = []
        var sourceSlots = Array.isArray(stored.slots) ? stored.slots : []
        for (var slotIndex = 0; slotIndex < sourceSlots.length; ++slotIndex) {
            var sourceSlot = sourceSlots[slotIndex]
            if (!sourceSlot || !Array.isArray(sourceSlot.items))
                continue
            var items = []
            for (var itemIndex = 0; itemIndex < sourceSlot.items.length; ++itemIndex) {
                if (root.saleItemHasData(sourceSlot.items[itemIndex]))
                    items.push(sourceSlot.items[itemIndex])
            }
            if (items.length)
                slots.push({ "index": Number(sourceSlot.index), "items": items })
        }
        slots.sort(function(first, second) { return first.index - second.index })
        stored.slots = slots
        return stored
    }

    function ensureSlotData() {
        if (!Array.isArray(root.eledata.slots))
            root.eledata.slots = []

        var normalizedSlots = []
        var previews = ({})
        for (var sourceIndex = 0; sourceIndex < root.eledata.slots.length; ++sourceIndex) {
            var storedSlot = root.eledata.slots[sourceIndex]
            if (Array.isArray(storedSlot))
                storedSlot = { "items": storedSlot }
            if (!storedSlot || typeof storedSlot !== "object")
                continue

            var slotIndex = storedSlot.index === undefined
                    ? sourceIndex : Number(storedSlot.index)
            if (!Number.isInteger(slotIndex) || slotIndex < 0
                    || slotIndex >= root.currentSlotCount)
                continue
            var sourceItems = Array.isArray(storedSlot.items) ? storedSlot.items : []
            var normalizedItems = []
            var previewIndex = 0
            for (var itemIndex = 0; itemIndex < sourceItems.length; ++itemIndex) {
                var normalized = root.normalizeSaleItem(sourceItems[itemIndex])
                if (!root.saleItemHasData(normalized))
                    continue
                if (sourceItems[itemIndex] && sourceItems[itemIndex].preview === true)
                    previewIndex = normalizedItems.length
                normalizedItems.push(normalized)
            }
            if (normalizedItems.length) {
                normalizedSlots.push({ "index": slotIndex, "items": normalizedItems })
                previews[String(slotIndex)] = Math.min(previewIndex,
                                                       normalizedItems.length - 1)
            }
        }
        normalizedSlots.sort(function(first, second) { return first.index - second.index })
        root.eledata.slots = normalizedSlots
        root.previewOffers = previews

        if (root.currentSlotIndex >= root.currentSlotCount)
            root.currentSlotIndex = -1
    }

    function slotRecordIndex(slotIndex) {
        if (!Array.isArray(root.eledata.slots))
            return -1
        for (var index = 0; index < root.eledata.slots.length; ++index) {
            if (Number(root.eledata.slots[index].index) === slotIndex)
                return index
        }
        return -1
    }

    function slotRecord(slotIndex, create) {
        var index = root.slotRecordIndex(slotIndex)
        if (index >= 0)
            return root.eledata.slots[index]
        if (create !== true)
            return null
        var record = { "index": slotIndex, "items": [] }
        root.eledata.slots.push(record)
        root.eledata.slots.sort(function(first, second) { return first.index - second.index })
        return record
    }

    function defaultLayoutFilter() {
        return { "scoreboard": "", "target": "", "score": "" }
    }

    function normalizeLayoutFilter(value) {
        var source = value && typeof value === "object" && !Array.isArray(value)
                ? value : ({})
        return {
            "scoreboard": typeof source.scoreboard === "string" ? source.scoreboard : "",
            "target": typeof source.target === "string" ? source.target : "",
            "score": typeof source.score === "string" ? source.score : ""
        }
    }

    function defaultLayoutInput() {
        return {
            "id": "",
            "enabled": false,
            "result": { "scoreboard": "", "target": "" },
            "defaultValue": "0",
            "connections": []
        }
    }

    function normalizeLayoutInput(value) {
        var source = value && typeof value === "object" && !Array.isArray(value)
                ? value : ({})
        var result = source.result && typeof source.result === "object"
                && !Array.isArray(source.result) ? source.result : ({})
        var sourceConnections = Array.isArray(source.connections)
                ? source.connections : []
        var connections = []
        for (var index = 0; index < sourceConnections.length; ++index) {
            var connection = sourceConnections[index]
            if (!connection || typeof connection !== "object"
                    || Array.isArray(connection))
                connection = ({})
            connections.push({
                "element": typeof connection.element === "string"
                           ? Global.projectRelativeElementPath(connection.element) : "",
                "value": typeof connection.value === "string" ? connection.value
                       : (typeof connection.value === "number"
                          ? String(connection.value) : "1")
            })
        }
        return {
            "id": typeof source.id === "string" ? source.id.trim() : "",
            "enabled": source.enabled === true,
            "result": {
                "scoreboard": typeof result.scoreboard === "string"
                              ? result.scoreboard : "",
                "target": typeof result.target === "string" ? result.target : ""
            },
            "defaultValue": typeof source.defaultValue === "string" ? source.defaultValue
                          : (typeof source.defaultValue === "number"
                             ? String(source.defaultValue) : ""),
            "connections": connections
        }
    }

    function createNestedGroupId(index) {
        return "nested-" + Date.now() + "-" + index + "-"
                + Math.floor(Math.random() * 1000000)
    }

    function ensureLayoutData() {
        var sourcePlaceholder = root.eledata.placeholderItem
        if (!sourcePlaceholder || typeof sourcePlaceholder !== "object"
                || Array.isArray(sourcePlaceholder))
            sourcePlaceholder = ({})
        root.eledata.placeholderItem = {
            "enabled": sourcePlaceholder.enabled === true,
            "element": typeof sourcePlaceholder.element === "string"
                    ? Global.projectRelativeElementPath(sourcePlaceholder.element) : ""
        }

        var sourceGroups = Array.isArray(root.eledata.nestedGroups)
                ? root.eledata.nestedGroups : []
        var groups = []
        var usedIds = ({})
        for (var groupIndex = 0; groupIndex < sourceGroups.length; ++groupIndex) {
            var sourceGroup = sourceGroups[groupIndex]
            if (!sourceGroup || typeof sourceGroup !== "object"
                    || Array.isArray(sourceGroup))
                sourceGroup = ({})

            var groupId = typeof sourceGroup.id === "string"
                    ? sourceGroup.id.trim() : ""
            if (!groupId.length || usedIds[groupId])
                groupId = root.createNestedGroupId(groupIndex)
            usedIds[groupId] = true

            var sourceSlots = Array.isArray(sourceGroup.slots) ? sourceGroup.slots : []
            var slots = []
            var usedSlots = ({})
            for (var slotIndex = 0; slotIndex < sourceSlots.length; ++slotIndex) {
                var numericSlot = Number(sourceSlots[slotIndex])
                if (!Number.isInteger(numericSlot) || numericSlot < 0
                        || numericSlot >= root.currentSlotCount || usedSlots[numericSlot])
                    continue
                usedSlots[numericSlot] = true
                slots.push(numericSlot)
            }
            slots.sort(function(first, second) { return first - second })

            groups.push({
                "id": groupId,
                "name": typeof sourceGroup.name === "string"
                        && sourceGroup.name.trim().length
                        ? sourceGroup.name.trim() : "嵌套组 " + (groupIndex + 1),
                "enabled": sourceGroup.enabled !== false,
                "element": typeof sourceGroup.element === "string"
                        ? Global.projectRelativeElementPath(sourceGroup.element) : "",
                "filter": root.normalizeLayoutFilter(sourceGroup.filter),
                "layoutInput": root.normalizeLayoutInput(sourceGroup.layoutInput),
                "slots": slots
            })
        }
        root.eledata.nestedGroups = groups

        if (root.nestedGroupIndex(root.selectedNestedGroupId) < 0) {
            root.selectedNestedGroupId = ""
            root.nestingDrawMode = false
        }
    }

    function placeholderData() {
        return root.eledata.placeholderItem || { "enabled": false, "element": "" }
    }

    function nestedGroups() {
        return Array.isArray(root.eledata.nestedGroups) ? root.eledata.nestedGroups : []
    }

    function nestedGroupIndex(groupId) {
        var groups = root.nestedGroups()
        for (var index = 0; index < groups.length; ++index) {
            if (groups[index].id === groupId)
                return index
        }
        return -1
    }

    function selectedNestedGroup() {
        var index = root.nestedGroupIndex(root.selectedNestedGroupId)
        return index >= 0 ? root.nestedGroups()[index] : null
    }

    function saveLayoutChange(refreshSlotPreviews) {
        var saved = root.updateDataOut()
        root.layoutRevision++
        root.layoutDataChanged()
        if (refreshSlotPreviews === true) {
            root.previewRevision++
            for (var index = 0; index < root.currentSlotCount; ++index)
                root.slotItemsChanged(index)
        }
        return saved
    }

    function notifyLayoutLoaded() {
        root.layoutRevision++
        root.layoutDataChanged()
    }

    function setPlaceholderEnabled(enabled) {
        root.eledata.placeholderItem.enabled = enabled === true
        root.saveLayoutChange(true)
    }

    function setPlaceholderElement(filePath) {
        root.eledata.placeholderItem.element = Global.projectRelativeElementPath(filePath)
        root.saveLayoutChange(true)
    }

    function uniqueNestedGroupName() {
        var groups = root.nestedGroups()
        var number = 1
        while (true) {
            var candidate = "嵌套组 " + number
            var exists = false
            for (var index = 0; index < groups.length; ++index) {
                if (groups[index].name === candidate) {
                    exists = true
                    break
                }
            }
            if (!exists)
                return candidate
            ++number
        }
    }

    function addNestedGroup() {
        var edit = root.beginWorkspaceEdit([], true)
        var groups = root.nestedGroups()
        var group = {
            "id": root.createNestedGroupId(groups.length),
            "name": root.uniqueNestedGroupName(),
            "enabled": true,
            "element": "",
            "filter": root.defaultLayoutFilter(),
            "layoutInput": root.defaultLayoutInput(),
            "slots": []
        }
        groups.push(group)
        root.selectedNestedGroupId = group.id
        root.nestingDrawMode = false
        root.saveLayoutChange(false)
        root.finishWorkspaceEdit(edit)
    }

    function selectNestedGroup(groupId) {
        if (root.selectedNestedGroupId === groupId) {
            root.selectBasicLayout()
            return
        }
        if (root.nestedGroupIndex(groupId) < 0)
            return
        inspector.finishEditing()
        root.selectedNestedGroupId = groupId
        root.nestingDrawMode = false
        root.layoutRevision++
        root.layoutDataChanged()
        if (root.isNestedGroupLayoutInputEnabled(groupId))
            inspector.showLayoutEditor()
    }

    function selectBasicLayout() {
        inspector.finishEditing()
        root.selectedNestedGroupId = ""
        root.nestingDrawMode = false
        root.layoutRevision++
        root.layoutDataChanged()
        inspector.leaveLayoutEditor()
    }

    function renameNestedGroup(groupId, name) {
        var index = root.nestedGroupIndex(groupId)
        var nextName = name === undefined || name === null ? "" : String(name).trim()
        if (index < 0 || !nextName.length || root.nestedGroups()[index].name === nextName)
            return
        root.nestedGroups()[index].name = nextName
        root.saveLayoutChange(false)
    }

    function removeNestedGroup(groupId) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return
        var edit = root.beginWorkspaceEdit([], true)
        root.nestedGroups().splice(index, 1)
        if (root.selectedNestedGroupId === groupId) {
            root.selectedNestedGroupId = ""
            root.nestingDrawMode = false
            inspector.leaveLayoutEditor()
        }
        root.saveLayoutChange(false)
        root.finishWorkspaceEdit(edit)
    }

    function moveNestedGroup(fromIndex, toIndex) {
        var groups = root.nestedGroups()
        if (fromIndex < 0 || fromIndex >= groups.length || toIndex < 0
                || toIndex >= groups.length || fromIndex === toIndex)
            return
        var edit = root.beginWorkspaceEdit([], true)
        var moved = groups.splice(fromIndex, 1)[0]
        groups.splice(toIndex, 0, moved)
        root.saveLayoutChange(false)
        root.finishWorkspaceEdit(edit)
    }

    function setNestedGroupEnabled(groupId, enabled) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return
        root.nestedGroups()[index].enabled = enabled === true
        root.saveLayoutChange(false)
    }

    function setNestedGroupElement(groupId, filePath) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return
        root.nestedGroups()[index].element = Global.projectRelativeElementPath(filePath)
        root.saveLayoutChange(false)
    }

    function setNestedGroupFilter(groupId, scoreboardName, targetName, scoreRange) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return
        root.nestedGroups()[index].filter = {
            "scoreboard": scoreboardName,
            "target": targetName,
            "score": scoreRange
        }
        root.saveLayoutChange(false)
    }

    function nestedGroupLayoutInput(groupId) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return root.defaultLayoutInput()
        return root.nestedGroups()[index].layoutInput
    }

    function isNestedGroupLayoutInputEnabled(groupId) {
        return root.nestedGroupLayoutInput(groupId).enabled === true
    }

    function setNestedGroupLayoutInputEnabled(groupId, enabled) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return
        root.nestedGroups()[index].layoutInput.enabled = enabled === true
        root.saveLayoutChange(false)
        if (enabled === true && root.selectedNestedGroupId === groupId)
            inspector.showLayoutEditor()
    }

    function setNestedGroupLayoutInputId(groupId, inputId) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return
        var nextId = inputId === undefined || inputId === null
                ? "" : String(inputId).trim()
        if (root.nestedGroups()[index].layoutInput.id === nextId)
            return
        root.nestedGroups()[index].layoutInput.id = nextId
        root.saveLayoutChange(false)
    }

    function setNestedGroupLayoutInputResult(groupId, scoreboardName, targetName) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return
        root.nestedGroups()[index].layoutInput.result = {
            "scoreboard": scoreboardName,
            "target": targetName
        }
        root.saveLayoutChange(false)
    }

    function setNestedGroupLayoutInputDefaultValue(groupId, value) {
        var index = root.nestedGroupIndex(groupId)
        if (index < 0)
            return
        var nextValue = value === undefined || value === null ? "" : String(value)
        if (!/^-?[0-9]+$/.test(nextValue) || nextValue.trim() !== nextValue)
            return
        var input = root.nestedGroups()[index].layoutInput
        if (input.defaultValue === nextValue)
            return
        input.defaultValue = nextValue
        root.saveLayoutChange(false)
    }

    function addNestedGroupLayoutInputConnection(groupId) {
        var input = root.nestedGroupLayoutInput(groupId)
        if (!input || !Array.isArray(input.connections))
            return
        input.connections.push({ "element": "", "value": "1" })
        root.saveLayoutChange(false)
    }

    function updateNestedGroupLayoutInputConnection(groupId, connectionIndex, filePath, value) {
        var input = root.nestedGroupLayoutInput(groupId)
        if (!input || !Array.isArray(input.connections)
                || connectionIndex < 0 || connectionIndex >= input.connections.length)
            return
        input.connections[connectionIndex].element = Global.projectRelativeElementPath(filePath)
        input.connections[connectionIndex].value = value === undefined || value === null
                ? "" : String(value)
        root.saveLayoutChange(false)
    }

    function removeNestedGroupLayoutInputConnection(groupId, connectionIndex) {
        var input = root.nestedGroupLayoutInput(groupId)
        if (!input || !Array.isArray(input.connections)
                || connectionIndex < 0 || connectionIndex >= input.connections.length)
            return
        input.connections.splice(connectionIndex, 1)
        root.saveLayoutChange(false)
    }

    function setNestingDrawMode(enabled) {
        root.nestingDrawMode = enabled === true && root.selectedNestedGroupId.length > 0
        root.layoutRevision++
        root.layoutDataChanged()
    }

    function groupContainsSlot(group, slotIndex) {
        return group && Array.isArray(group.slots)
                && group.slots.indexOf(slotIndex) >= 0
    }

    function isSlotInSelectedNestedGroup(slotIndex) {
        var revision = root.layoutRevision
        return root.groupContainsSlot(root.selectedNestedGroup(), slotIndex)
    }

    function isSlotNested(slotIndex) {
        var revision = root.layoutRevision
        var groups = root.nestedGroups()
        for (var index = 0; index < groups.length; ++index) {
            if (groups[index].enabled === true
                    && root.groupContainsSlot(groups[index], slotIndex))
                return true
        }
        return false
    }

    function toggleNestedSlot(slotIndex) {
        if (!root.nestingDrawMode)
            return
        var group = root.selectedNestedGroup()
        if (!group)
            return
        var edit = root.beginWorkspaceEdit([], false, group)
        var index = group.slots.indexOf(slotIndex)
        if (index >= 0)
            group.slots.splice(index, 1)
        else {
            group.slots.push(slotIndex)
            group.slots.sort(function(first, second) { return first - second })
        }
        root.saveLayoutChange(false)
        root.finishWorkspaceEdit(edit)
    }

    function slotItems(slotIndex) {
        var slot = root.slotRecord(slotIndex, false)
        return slot && Array.isArray(slot.items) ? slot.items : []
    }

    function previewItemIndex(slotIndex) {
        var items = root.slotItems(slotIndex)
        if (!items.length)
            return -1
        var stored = Number(root.previewOffers[String(slotIndex)])
        return Number.isInteger(stored) && stored >= 0 && stored < items.length
                ? stored : 0
    }

    function previewItemForSlot(slotIndex) {
        // previewRevision intentionally participates in this lookup so QML
        // bindings refresh after an in-place JSON-array mutation.
        var revision = root.previewRevision
        var items = root.slotItems(slotIndex)
        var index = root.previewItemIndex(slotIndex)
        var selectedItem = index >= 0 && typeof items[index].element === "string"
                ? items[index].element : ""
        if (selectedItem.length)
            return selectedItem
        var placeholder = root.placeholderData()
        return placeholder.enabled === true && typeof placeholder.element === "string"
                ? placeholder.element : ""
    }

    function notifySlotChanged(slotIndex) {
        root.previewRevision++
        root.slotItemsChanged(slotIndex)
    }

    function saveSlotChange(slotIndex) {
        var saved = root.updateDataOut()
        root.notifySlotChanged(slotIndex)
        return saved
    }

    function setCurrentSlot(slotIndex) {
        if (slotIndex < 0 || slotIndex >= root.currentSlotCount)
            return
        inspector.finishEditing()
        root.currentSlotIndex = slotIndex
        inspector.showSlotEditor()
    }

    function clearCurrentSlot() {
        inspector.finishEditing()
        root.currentSlotIndex = -1
        inspector.clearSlotEditor()
    }

    function addSaleItem(slotIndex) {
        if (slotIndex < 0 || slotIndex >= root.currentSlotCount)
            return
        var edit = root.beginWorkspaceEdit([slotIndex])
        var slot = root.slotRecord(slotIndex, true)
        slot.items.push(root.defaultSaleItem())
        root.saveSlotChange(slotIndex)
        root.finishWorkspaceEdit(edit)
    }

    function updateSaleItemElement(slotIndex, itemIndex, filePath) {
        inspector.finishEditing()
        var items = root.slotItems(slotIndex)
        if (itemIndex < 0 || itemIndex >= items.length)
            return
        var path = Global.projectRelativeElementPath(filePath)
        if (items[itemIndex].element === path)
            return
        var edit = root.beginWorkspaceEdit([slotIndex])
        items[itemIndex].element = path
        root.saveSlotChange(slotIndex)
        root.finishWorkspaceEdit(edit)
    }

    function updateSaleItemFilter(slotIndex, itemIndex, scoreboardName,
                                  targetName, scoreRange) {
        var items = root.slotItems(slotIndex)
        if (itemIndex < 0 || itemIndex >= items.length)
            return
        items[itemIndex].filter = {
            "scoreboard": scoreboardName,
            "target": targetName,
            "score": scoreRange
        }
        root.saveSlotChange(slotIndex)
    }

    function updateSaleItemMacros(slotIndex, itemIndex, macros) {
        var items = root.slotItems(slotIndex)
        if (itemIndex < 0 || itemIndex >= items.length)
            return
        items[itemIndex].macros = Array.isArray(macros) ? macros : []
        root.saveSlotChange(slotIndex)
    }

    function setPreviewSaleItem(slotIndex, itemIndex, checked) {
        var items = root.slotItems(slotIndex)
        if (itemIndex < 0 || itemIndex >= items.length)
            return

        // A slot always has one preview item. The checked control therefore
        // behaves like a visually familiar checkbox with radio semantics.
        if (!checked && root.previewItemIndex(slotIndex) === itemIndex) {
            root.notifySlotChanged(slotIndex)
            return
        }
        if (!checked)
            return
        var previews = Object.assign({}, root.previewOffers)
        previews[String(slotIndex)] = itemIndex
        root.previewOffers = previews
        root.notifySlotChanged(slotIndex)
    }

    function moveSaleItem(slotIndex, fromIndex, toIndex) {
        inspector.finishEditing()
        var items = root.slotItems(slotIndex)
        if (fromIndex < 0 || fromIndex >= items.length
                || toIndex < 0 || toIndex >= items.length || fromIndex === toIndex)
            return
        var edit = root.beginWorkspaceEdit([slotIndex])
        var previewIndex = root.previewItemIndex(slotIndex)
        var moved = items.splice(fromIndex, 1)[0]
        items.splice(toIndex, 0, moved)
        var previews = Object.assign({}, root.previewOffers)
        if (previewIndex === fromIndex)
            previews[String(slotIndex)] = toIndex
        else if (fromIndex < previewIndex && toIndex >= previewIndex)
            previews[String(slotIndex)] = previewIndex - 1
        else if (fromIndex > previewIndex && toIndex <= previewIndex)
            previews[String(slotIndex)] = previewIndex + 1
        root.previewOffers = previews
        root.saveSlotChange(slotIndex)
        root.finishWorkspaceEdit(edit)
    }

    function swapSlotItems(sourceIndex, targetIndex) {
        if (!root.editorReady || root.nestingDrawMode || sourceIndex === targetIndex
                || sourceIndex < 0 || sourceIndex >= root.currentSlotCount
                || targetIndex < 0 || targetIndex >= root.currentSlotCount)
            return false
        inspector.finishEditing()
        var source = root.slotRecord(sourceIndex, false)
        if (!source || !source.items.length)
            return false
        var edit = root.beginWorkspaceEdit([sourceIndex, targetIndex])
        var target = root.slotRecord(targetIndex, false)
        var sourcePreview = root.previewItemIndex(sourceIndex)
        var targetPreview = root.previewItemIndex(targetIndex)
        source.index = targetIndex
        if (target)
            target.index = sourceIndex
        root.eledata.slots.sort(function(first, second) { return first.index - second.index })
        var previews = Object.assign({}, root.previewOffers)
        previews[String(targetIndex)] = sourcePreview
        if (targetPreview < 0)
            delete previews[String(sourceIndex)]
        else
            previews[String(sourceIndex)] = targetPreview
        root.previewOffers = previews
        var saved = root.updateDataOut()
        root.notifySlotChanged(sourceIndex)
        root.notifySlotChanged(targetIndex)
        root.setCurrentSlot(targetIndex)
        root.finishWorkspaceEdit(edit)
        return saved
    }

    function clearSlotItems(slotIndex) {
        if (slotIndex < 0 || slotIndex >= root.currentSlotCount)
            return
        inspector.finishEditing()
        var recordIndex = root.slotRecordIndex(slotIndex)
        if (recordIndex < 0)
            return
        var edit = root.beginWorkspaceEdit([slotIndex])
        root.eledata.slots.splice(recordIndex, 1)
        var previews = Object.assign({}, root.previewOffers)
        delete previews[String(slotIndex)]
        root.previewOffers = previews
        root.saveSlotChange(slotIndex)
        root.finishWorkspaceEdit(edit)
    }

    function removeSaleItem(slotIndex, itemIndex) {
        inspector.finishEditing()
        var items = root.slotItems(slotIndex)
        if (itemIndex < 0 || itemIndex >= items.length)
            return
        var edit = root.beginWorkspaceEdit([slotIndex])
        var previewIndex = root.previewItemIndex(slotIndex)
        items.splice(itemIndex, 1)
        var previews = Object.assign({}, root.previewOffers)
        if (!items.length) {
            var recordIndex = root.slotRecordIndex(slotIndex)
            if (recordIndex >= 0)
                root.eledata.slots.splice(recordIndex, 1)
            delete previews[String(slotIndex)]
        } else if (previewIndex === itemIndex) {
            previews[String(slotIndex)] = Math.min(itemIndex, items.length - 1)
        } else if (itemIndex < previewIndex) {
            previews[String(slotIndex)] = previewIndex - 1
        }
        root.previewOffers = previews
        root.saveSlotChange(slotIndex)
        root.finishWorkspaceEdit(edit)
    }

    function setSlotPreviewElement(slotIndex, filePath) {
        if (slotIndex < 0 || slotIndex >= root.currentSlotCount)
            return
        inspector.finishEditing()
        var items = root.slotItems(slotIndex)
        var itemIndex = root.previewItemIndex(slotIndex)
        if (!items.length || itemIndex < 0) {
            var edit = root.beginWorkspaceEdit([slotIndex])
            var item = root.defaultSaleItem()
            item.element = Global.projectRelativeElementPath(filePath)
            root.slotRecord(slotIndex, true).items.push(item)
            root.saveSlotChange(slotIndex)
            root.finishWorkspaceEdit(edit)
            return
        }
        root.updateSaleItemElement(slotIndex, itemIndex, filePath)
    }

    function setContainerType(containerTypeName) {
        var interfaceId = root.layoutKinds.indexOf(containerTypeName)
        if (interfaceId < 0)
            return false

        root.eledata.containerType = containerTypeName
        if (!root.updateDataOut())
            return false

        root.containerType = interfaceId
        root.changingContainerType = false
        root.ensureSlotData()
        root.ensureLayoutData()
        root.updateDataOut()
        root.notifyLayoutLoaded()
        root.notifySlotChanged(root.currentSlotIndex)
        root.clearWorkspaceHistory()
        return true
    }

    function beginContainerTypeChange() {
        if (!root.dataLoaded)
            return
        if (root.containerType >= 0)
            containerTypeSelection.selectedContainerType = root.layoutKinds[root.containerType]
        else if (root.containerTypeOptions.length)
            containerTypeSelection.selectedContainerType = root.containerTypeOptions[0].type
        root.changingContainerType = true
    }

    function cancelContainerTypeChange() {
        root.changingContainerType = false
    }

    function setCustomName(value) {
        var nextValue = value === undefined || value === null ? "" : String(value)
        root.eledata.customName = nextValue
        if (!root.updateDataOut())
            return false
        root.customName = nextValue
        return true
    }

    function setOpenCommand(value) {
        var nextValue = value === undefined || value === null ? "" : String(value)
        root.eledata.openCommand = nextValue
        if (!root.updateDataOut())
            return false
        root.openCommand = nextValue
        return true
    }

    function elementReading() {
        root.clearWorkspaceHistory()
        root.pageInitialized = false
        root.containerType = -1
        root.changingContainerType = false
        root.customName = typeof root.eledata.customName === "string"
                ? root.eledata.customName : ""
        root.openCommand = typeof root.eledata.openCommand === "string"
                ? root.eledata.openCommand : ""
        root.eledata.customName = root.customName
        root.eledata.openCommand = root.openCommand
        if (root.eledata.containerType === undefined
                || root.eledata.containerType === null)
            root.eledata.containerType = ""
        if (!root.eledata.placeholderItem
                || typeof root.eledata.placeholderItem !== "object")
            root.eledata.placeholderItem = { "enabled": false, "element": "" }
        if (!Array.isArray(root.eledata.slots))
            root.eledata.slots = []
        if (!Array.isArray(root.eledata.nestedGroups))
            root.eledata.nestedGroups = []

        var storedInterfaceId = root.layoutKinds.indexOf(root.eledata.containerType)
        delete root.eledata.container
        if (Number.isInteger(storedInterfaceId)
                && storedInterfaceId >= 0
                && storedInterfaceId < Constants.containerCount.length) {
            root.containerType = storedInterfaceId
            root.ensureSlotData()
            root.ensureLayoutData()
            root.updateDataOut()
            root.notifyLayoutLoaded()
            root.notifySlotChanged(root.currentSlotIndex)
            root.pageInitialized = true
            return
        }

        if (root.containerTypeOptions.length)
            containerTypeSelection.selectedContainerType = root.containerTypeOptions[0].type
        root.eledata.containerType = ""
        root.updateDataOut()
        root.pageInitialized = true
    }

    property int inspectorWidth: Global.uiInspectorWidth
    property int minimumInspectorWidth: 260
    property int minimumWorkspaceWidth: 460
    property int pageMargin: 10
    property int panelSpacing: 10
    readonly property int maximumInspectorWidth: Math.max(
                                                     minimumInspectorWidth,
                                                     width - minimumWorkspaceWidth
                                                     - pageMargin * 2
                                                     - panelSpacing)

    Item {
        id: editorWorkspace
        anchors.fill: parent
        visible: opacity > 0.01
        enabled: visible
        opacity: root.editorReady ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 220 / Global.animationSpeed; easing.type: Easing.OutCubic }
        }

        LayoutManager {
            id: layoutBar
            x: root.pageMargin
            y: root.pageMargin
            width: Math.max(0, inspector.x - root.panelSpacing - x)
            z: 1
            uiPage: root
        }

        Rectangle {
            id: canvasArea
            x: layoutBar.x
            y: layoutBar.y + layoutBar.height + root.panelSpacing
            width: layoutBar.width
            height: Math.max(0, parent.height - y - root.pageMargin)
            radius: 10
            color: Colors.changeA(Colors.card, 0.18)
            border.width: 1
            border.color: Colors.changeA(Colors.outline, 0.07)

            ContainerBox {
                anchors.fill: parent
                containerType: root.containerType
                uiPage: root
                viewKey: Global.normalizeElementPath(Global.get_filePath())
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: canvasArea.width
                        height: canvasArea.height
                        radius: canvasArea.radius
                    }
                }
            }
        }

        Inspector {
            id: inspector
            uiPage: root
            x: parent.width - root.pageMargin - width
            y: root.pageMargin
            height: Math.max(0, parent.height - root.pageMargin * 2)
            desiredWidth: root.inspectorWidth
            minimumWidth: root.minimumInspectorWidth
            maximumWidth: root.maximumInspectorWidth

            onWidthRequested: function(width) {
                root.inspectorWidth = width
            }
            onWidthResizeFinished: Global.saveUiInspectorWidth(root.inspectorWidth)
        }
    }

    ContainerTypeSelection {
        id: containerTypeSelection
        z: 1
        visible: root.pageInitialized && opacity > 0.01
        enabled: visible
        opacity: !root.pageInitialized ? 0 : (root.editorReady ? 0 : 1)
        containerTypeOptions: root.containerTypeOptions
        showCancelButton: root.changingContainerType

        Behavior on opacity {
            NumberAnimation { duration: 220 / Global.animationSpeed; easing.type: Easing.OutCubic }
        }

        onConfirmed: function(containerTypeName) {
            root.setContainerType(containerTypeName)
        }
        onCanceled: root.cancelContainerTypeChange()
    }
}
