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
            return
        }

        if (root.containerOptions.length)
            containerTypeSelection.selectedContainerId = root.containerOptions[0].id
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
        visible: opacity > 0.01
        enabled: visible
        opacity: root.editorReady ? 0 : 1
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
