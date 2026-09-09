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

        if (root.currentSlotCount > 0
                && (root.currentSlotIndex < 0
                    || root.currentSlotIndex >= root.currentSlotCount))
            root.currentSlotIndex = 0
        else if (root.currentSlotCount === 0)
            root.currentSlotIndex = -1
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
        return index >= 0 && typeof items[index].element === "string"
                ? items[index].element : ""
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
        root.updateDataOut()
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
            root.updateDataOut()
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
    property int minimumWorkspaceWidth: 280
    property int layoutBarHeight: 72
    property int minimumLayoutBarHeight: 72
    property int minimumCanvasHeight: 200
    property int pageMargin: 10
    property int panelSpacing: 10
    readonly property int maximumInspectorWidth: Math.max(
                                                     minimumInspectorWidth,
                                                     width - minimumWorkspaceWidth
                                                     - pageMargin * 2
                                                     - panelSpacing)
    readonly property int maximumLayoutBarHeight: Math.max(
                                                       minimumLayoutBarHeight,
                                                       height - pageMargin * 2
                                                       - panelSpacing - minimumCanvasHeight)

    Item {
        id: editorWorkspace
        anchors.fill: parent
        visible: opacity > 0.01
        enabled: visible
        opacity: root.editorReady ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        LayoutManager {
            id: layoutBar
            x: root.pageMargin
            y: root.pageMargin
            width: Math.max(0, inspector.x - root.panelSpacing - x)
            z: 1
            desiredHeight: root.layoutBarHeight
            minimumHeight: root.minimumLayoutBarHeight
            maximumHeight: root.maximumLayoutBarHeight

            onHeightRequested: function(height) {
                root.layoutBarHeight = height
            }
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
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        onConfirmed: function(containerId) {
            root.setContainerType(containerId)
        }
        onCanceled: root.cancelContainerTypeChange()
    }
}
