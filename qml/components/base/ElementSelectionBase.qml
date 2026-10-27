import QtQuick
import xcshop

// Shared selection state, validation, drag/drop and SignalBus lifecycle.
Rectangle {
    id: root
    property Item dropTarget: root

    property string selectionId: ""
    property string selectedElementPath: ""
    property bool waitingForSelection: false
    property bool externalDragActive: false
    property bool dropHovered: false
    property string validationMessage: ""
    property bool connectedElementHovered: false

    readonly property bool hasSelection: selectedElementPath.length > 0
    readonly property bool highlighted: waitingForSelection || externalDragActive || dropHovered
    readonly property string elementIconSource: {
        switch (selectionId.toLowerCase()) {
        case "ui":
            return "qrc:/assets/gui/element/UI.png"
        case "item":
            return "qrc:/assets/gui/element/Item.png"
        case "cost":
            return "qrc:/assets/gui/element/Cost.png"
        case "display":
            return "qrc:/assets/gui/element/Display.png"
        default:
            return "qrc:/assets/gui/element/File_" + Colors.gui_theme + ".png"
        }
    }
    readonly property string selectionTypeName: {
        switch (selectionId.toLowerCase()) {
        case "ui":
            return "界面元素"
        case "item":
            return "商品元素"
        case "cost":
            return "代价元素"
        case "display":
            return "展示元素"
        default:
            return "元素"
        }
    }
    readonly property string selectedElementName: {
        if (!selectedElementPath.length)
            return ""
        var parts = selectedElementPath.replace(/\\/g, "/").split("/")
        return parts.length ? parts[parts.length - 1] : selectedElementPath
    }
    readonly property string selectedElementDisplayPath: {
        var path = Global.normalizeElementPath(selectedElementPath)
        var projectRoot = Global.normalizeElementPath(Global.project_location)
        if (projectRoot.length && path.indexOf(projectRoot + "/") === 0)
            return "project:/" + path.substring(projectRoot.length + 1)
        return path
    }
    readonly property string placeholderText: {
        if (validationMessage.length)
            return validationMessage
        if (waitingForSelection)
            return "请在元素中转区选择" + selectionTypeName
        if (externalDragActive || dropHovered)
            return "松开以连接" + selectionTypeName
        return "选择或拖放" + selectionTypeName
    }

    signal selectionRequested(string selectionId)
    signal selectionCancelled(string selectionId)
    signal elementSelected(string filePath)
    signal selectionCleared

    width: 380
    height: 44
    radius: 8
    color: highlighted ? Colors.changeA(Colors.border, 0.12) : Colors.changeA(Colors.input, 0.30)
    border.width: 1
    border.color: highlighted ? Colors.changeA(Colors.border, 0.82) : Colors.changeA(Colors.outline, 0.11)

    Behavior on border.color {
        ColorAnimation {
            duration: 160 / Global.animationSpeed
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 160 / Global.animationSpeed
        }
    }

    function normalizedPath(filePath) {
        return Global.resolveElementPath(filePath)
    }

    function setElement(filePath, notifyChange) {
        var path = normalizedPath(filePath)
        if (!path.length) {
            clearElement(notifyChange)
            return
        }
        var element = Global.parseElementPath(path)
        if (!element || (selectionId.length && element.type.toLowerCase() !== selectionId.toLowerCase())) {
            validationMessage = "仅可连接" + selectionTypeName
            validationTimer.restart()
            return
        }
        path = element.path
        var wasWaiting = waitingForSelection
        selectedElementPath = path
        waitingForSelection = false
        validationMessage = ""
        if (wasWaiting)
            SignalBus.elementSelectionFocusChanged(false, {})
        if (notifyChange === undefined || notifyChange)
            elementSelected(element.relativePath)
    }

    function clearElement(notifyChange) {
        var wasWaiting = waitingForSelection
        selectedElementPath = ""
        waitingForSelection = false
        if (wasWaiting) {
            SignalBus.elementSelectionFocusChanged(false, {})
            SignalBus.elementSelectionCancelled(selectionId)
        }
        if (notifyChange === undefined || notifyChange)
            selectionCleared()
    }

    function requestElementSelection() {
        SignalBus.elementSelectionRequestActivated(root)
        waitingForSelection = true
        updateFocusGeometry()
        selectionRequested(selectionId)
        SignalBus.elementSelectionRequested(selectionId)
    }

    function cancelElementSelection() {
        waitingForSelection = false
        SignalBus.elementSelectionFocusChanged(false, {})
        selectionCancelled(selectionId)
        SignalBus.elementSelectionCancelled(selectionId)
    }

    function openConnectedElement() {
        if (hasSelection)
            SignalBus.elementOpenRequested(selectedElementPath)
    }

    function updateFocusGeometry() {
        if (!waitingForSelection)
            return
        var point = mapToItem(null, 0, 0)
        SignalBus.elementSelectionFocusChanged(true, {
            "x": point.x,
            "y": point.y,
            "width": width,
            "height": height
        })
    }

    Timer {
        id: focusGeometryTimer
        interval: 40
        repeat: true
        running: root.waitingForSelection
        onTriggered: root.updateFocusGeometry()
    }

    Timer {
        id: validationTimer
        interval: 1800
        onTriggered: root.validationMessage = ""
    }

    Connections {
        target: SignalBus

        function onElementSelectionDeselect() {
            root.cancelElementSelection()
        }

        function onElementSelectionRequestActivated(selectionItem) {
            if (selectionItem !== root)
                root.waitingForSelection = false
        }

        function onElementSelectionResolved(filePath) {
            if (root.waitingForSelection)
                root.setElement(filePath, true)
        }

        function onElementDragStateChanged(active) {
            root.externalDragActive = active
        }
    }

    DropArea {
        parent: root.dropTarget
        anchors.fill: parent
        keys: ["xcshop-element"]
        onEntered: function (drag) {
            root.dropHovered = true
            drag.acceptProposedAction()
        }
        onExited: root.dropHovered = false
        onDropped: function (drop) {
            root.dropHovered = false
            var path = SignalBus.draggedElementPath
            if (!path.length && drop.hasText)
                path = drop.text
            if (!path.length && drop.hasUrls && drop.urls.length)
                path = drop.urls[0].toString()
            if (path.length) {
                root.setElement(path, true)
                drop.acceptProposedAction()
            }
        }
    }

    onVisibleChanged: {
        if (!visible && waitingForSelection)
            cancelElementSelection()
    }

    Component.onDestruction: {
        if (waitingForSelection) {
            SignalBus.elementSelectionFocusChanged(false, {})
            SignalBus.elementSelectionCancelled(selectionId)
        }
    }
}
