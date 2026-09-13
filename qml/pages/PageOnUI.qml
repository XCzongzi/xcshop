pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import Qt5Compat.GraphicalEffects

BaseIOPage {
    id: root
    color: Colors.transparent
    workspace: true

    // This is the resource/interface number (0-5), not the selected block ID.
    property int containerType: -1
    property string containerId: ""
    property string customName: ""
    property string openCommand: ""
    property bool changingContainerType: false
    property bool pageInitialized: false
    property int currentSlotIndex: -1
    property int previewRevision: 0
    property int layoutRevision: 0
    property string selectedNestedGroupId: ""
    property bool nestingDrawMode: false
    // These two properties are the selection-page interfaces: callers may set
    // them when creating PageOnUI to hide entity containers or large chests.
    property bool showEntityContainers: true
    property bool showLargeChests: true
    readonly property var blockContainerOptions: containerCatalog.blockContainers(showLargeChests)
    readonly property var entityContainerOptions: containerCatalog.entityContainers(showEntityContainers)
    readonly property var containerOptions: blockContainerOptions.concat(entityContainerOptions)
    readonly property bool containerConfigured: containerType >= 0
    readonly property bool editorReady: dataLoaded && containerConfigured
                                      && !changingContainerType
    readonly property int currentSlotCount: containerType >= 0
                                            && containerType < Constants.containerCount.length
                                            ? Constants.containerCount[containerType] : 0
    readonly property string currentContainerTypeLabel: {
        var label = containerCatalog.labelForContainer(containerId)
        if (label.length)
            return label
        var interfaceLabels = ["普通容器（27 格）", "大型箱子（54 格）",
                               "发射器／投掷器（9 格）", "漏斗（5 格）",
                               "酿造台（5 格）", "熔炉类（3 格）"]
        return containerType >= 0 && containerType < interfaceLabels.length
                ? interfaceLabels[containerType] : "未选择"
    }

    ContainerCatalog {
        id: containerCatalog
    }

    signal slotItemsChanged(int slotIndex)
    signal layoutDataChanged()

    function defaultSaleItem(preview) {
        return {
            "preview": preview === true,
            "element": "",
            "filter": { "scoreboard": "", "target": "", "score": "" }
        }
    }

    function normalizeSaleItem(value, preview) {
        var source = value && typeof value === "object" && !Array.isArray(value)
                ? value : ({})
        var filter = source.filter && typeof source.filter === "object"
                && !Array.isArray(source.filter) ? source.filter : ({})
        return {
            "preview": preview === true,
            "element": typeof source.element === "string" ? source.element : "",
            "filter": {
                "scoreboard": typeof filter.scoreboard === "string" ? filter.scoreboard : "",
                "target": typeof filter.target === "string" ? filter.target : "",
                "score": typeof filter.score === "string" ? filter.score : ""
            }
        }
    }

    function ensureSlotData() {
        if (!Array.isArray(root.eledata.slots))
            root.eledata.slots = []

        for (var slotIndex = 0; slotIndex < root.currentSlotCount; ++slotIndex) {
            var storedSlot = root.eledata.slots[slotIndex]
            if (Array.isArray(storedSlot))
                storedSlot = { "items": storedSlot }
            if (!storedSlot || typeof storedSlot !== "object")
                storedSlot = { "items": [] }

            var sourceItems = Array.isArray(storedSlot.items) ? storedSlot.items : []
            if (!sourceItems.length)
                sourceItems = [root.defaultSaleItem(true)]

            var previewIndex = -1
            for (var itemIndex = 0; itemIndex < sourceItems.length; ++itemIndex) {
                if (previewIndex < 0 && sourceItems[itemIndex]
                        && sourceItems[itemIndex].preview === true)
                    previewIndex = itemIndex
            }
            if (previewIndex < 0)
                previewIndex = 0

            var normalizedItems = []
            for (var normalizeIndex = 0; normalizeIndex < sourceItems.length; ++normalizeIndex)
                normalizedItems.push(root.normalizeSaleItem(sourceItems[normalizeIndex],
                                                             normalizeIndex === previewIndex))
            root.eledata.slots[slotIndex] = { "items": normalizedItems }
        }

        if (root.currentSlotIndex >= root.currentSlotCount)
            root.currentSlotIndex = -1
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
        var groups = root.nestedGroups()
        var group = {
            "id": root.createNestedGroupId(groups.length),
            "name": root.uniqueNestedGroupName(),
            "enabled": true,
            "element": "",
            "filter": root.defaultLayoutFilter(),
            "slots": []
        }
        groups.push(group)
        root.selectedNestedGroupId = group.id
        root.nestingDrawMode = false
        root.saveLayoutChange(false)
    }

    function selectNestedGroup(groupId) {
        if (root.selectedNestedGroupId === groupId) {
            root.selectBasicLayout()
            return
        }
        if (root.nestedGroupIndex(groupId) < 0)
            return
        root.selectedNestedGroupId = groupId
        root.nestingDrawMode = false
        root.layoutRevision++
        root.layoutDataChanged()
    }

    function selectBasicLayout() {
        root.selectedNestedGroupId = ""
        root.nestingDrawMode = false
        root.layoutRevision++
        root.layoutDataChanged()
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
        root.nestedGroups().splice(index, 1)
        if (root.selectedNestedGroupId === groupId) {
            root.selectedNestedGroupId = ""
            root.nestingDrawMode = false
        }
        root.saveLayoutChange(false)
    }

    function moveNestedGroup(fromIndex, toIndex) {
        var groups = root.nestedGroups()
        if (fromIndex < 0 || fromIndex >= groups.length || toIndex < 0
                || toIndex >= groups.length || fromIndex === toIndex)
            return
        var moved = groups.splice(fromIndex, 1)[0]
        groups.splice(toIndex, 0, moved)
        root.saveLayoutChange(false)
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
        var index = group.slots.indexOf(slotIndex)
        if (index >= 0)
            group.slots.splice(index, 1)
        else {
            group.slots.push(slotIndex)
            group.slots.sort(function(first, second) { return first - second })
        }
        root.saveLayoutChange(false)
    }

    function slotItems(slotIndex) {
        if (!Array.isArray(root.eledata.slots)
                || slotIndex < 0 || slotIndex >= root.eledata.slots.length)
            return []
        var slot = root.eledata.slots[slotIndex]
        return slot && Array.isArray(slot.items) ? slot.items : []
    }

    function previewItemIndex(slotIndex) {
        var items = root.slotItems(slotIndex)
        for (var index = 0; index < items.length; ++index) {
            if (items[index].preview === true)
                return index
        }
        return items.length ? 0 : -1
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
        root.currentSlotIndex = slotIndex
    }

    function clearCurrentSlot() {
        root.currentSlotIndex = -1
    }

    function addSaleItem(slotIndex) {
        var items = root.slotItems(slotIndex)
        if (!items.length)
            return
        items.push(root.defaultSaleItem(false))
        root.saveSlotChange(slotIndex)
    }

    function updateSaleItemElement(slotIndex, itemIndex, filePath) {
        var items = root.slotItems(slotIndex)
        if (itemIndex < 0 || itemIndex >= items.length)
            return
        items[itemIndex].element = Global.projectRelativeElementPath(filePath)
        root.saveSlotChange(slotIndex)
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

    function setPreviewSaleItem(slotIndex, itemIndex, checked) {
        var items = root.slotItems(slotIndex)
        if (itemIndex < 0 || itemIndex >= items.length)
            return

        // A slot always has one preview item. The checked control therefore
        // behaves like a visually familiar checkbox with radio semantics.
        if (!checked && items[itemIndex].preview === true) {
            root.notifySlotChanged(slotIndex)
            return
        }
        if (!checked)
            return
        for (var index = 0; index < items.length; ++index)
            items[index].preview = index === itemIndex
        root.saveSlotChange(slotIndex)
    }

    function moveSaleItem(slotIndex, fromIndex, toIndex) {
        var items = root.slotItems(slotIndex)
        if (fromIndex < 0 || fromIndex >= items.length
                || toIndex < 0 || toIndex >= items.length || fromIndex === toIndex)
            return
        var moved = items.splice(fromIndex, 1)[0]
        items.splice(toIndex, 0, moved)
        root.saveSlotChange(slotIndex)
    }

    function removeSaleItem(slotIndex, itemIndex) {
        var items = root.slotItems(slotIndex)
        if (items.length <= 1 || itemIndex < 0 || itemIndex >= items.length)
            return
        var removedPreview = items[itemIndex].preview === true
        items.splice(itemIndex, 1)
        if (removedPreview)
            items[Math.min(itemIndex, items.length - 1)].preview = true
        root.saveSlotChange(slotIndex)
    }

    function setSlotPreviewElement(slotIndex, filePath) {
        var items = root.slotItems(slotIndex)
        var itemIndex = root.previewItemIndex(slotIndex)
        if (!items.length || itemIndex < 0)
            return
        root.updateSaleItemElement(slotIndex, itemIndex, filePath)
    }

    function setContainerType(containerId) {
        var interfaceId = containerCatalog.interfaceForContainer(containerId)
        if (interfaceId < 0)
            return false

        root.eledata.container = containerId
        root.eledata.containerType = interfaceId
        if (!root.updateDataOut())
            return false

        root.containerId = containerId
        root.containerType = interfaceId
        root.changingContainerType = false
        root.ensureSlotData()
        root.ensureLayoutData()
        root.updateDataOut()
        root.notifyLayoutLoaded()
        root.notifySlotChanged(root.currentSlotIndex)
        return true
    }

    function beginContainerTypeChange() {
        if (!root.dataLoaded)
            return
        if (root.containerId.length)
            containerTypeSelection.selectedContainerId = root.containerId
        else if (root.containerOptions.length)
            containerTypeSelection.selectedContainerId = root.containerOptions[0].id
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
        root.pageInitialized = false
        root.containerId = typeof root.eledata.container === "string"
                ? root.eledata.container : ""
        root.customName = typeof root.eledata.customName === "string"
                ? root.eledata.customName : ""
        root.openCommand = typeof root.eledata.openCommand === "string"
                ? root.eledata.openCommand : ""

        var storedInterfaceId = Number(root.eledata.containerType)
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

        if (root.containerOptions.length)
            containerTypeSelection.selectedContainerId = root.containerOptions[0].id
        root.pageInitialized = true
    }

    property int inspectorWidth: 260
    property int minimumInspectorWidth: 200
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
            color: Colors.changeA(Colors.foreground, 0.18)
            border.width: 1
            border.color: Colors.changeA(Colors.text, 0.07)

            ContainerBox {
                anchors.fill: parent
                containerType: root.containerType
                uiPage: root
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
        }
    }

    ContainerTypeSelection {
        id: containerTypeSelection
        z: 1
        visible: root.pageInitialized && opacity > 0.01
        enabled: visible
        opacity: !root.pageInitialized ? 0 : (root.editorReady ? 0 : 1)
        blockContainerOptions: root.blockContainerOptions
        entityContainerOptions: root.entityContainerOptions
        showEntityContainers: root.showEntityContainers
        showCancelButton: root.changingContainerType

        Behavior on opacity {
            NumberAnimation { duration: 220 / Global.animationSpeed; easing.type: Easing.OutCubic }
        }

        onConfirmed: function(containerId) {
            root.setContainerType(containerId)
        }
        onCanceled: root.cancelContainerTypeChange()
    }
}
