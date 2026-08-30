import QtQuick
import xcshop

Rectangle {
    id: root

    property int size: 64
    property string selectionId: "item"
    property string selectedElementPath: ""
    property bool waitingForSelection: false
    property bool externalDragActive: false
    property bool dropHovered: false
    property bool lit: false

    readonly property bool isItemSlot: true
    readonly property bool hasSelection: selectedElementPath.length > 0
    readonly property string defaultIconSource: "qrc:/assets/gui/element/Item.png"
    readonly property string iconSource: storedItemIconSource()

    signal selectionRequested(string selectionId)
    signal selectionCancelled(string selectionId)
    signal elementSelected(string filePath)
    signal selectionCleared()

    width: size
    height: size
    radius: 0
    color: lit || slotMouse.containsMouse || dropHovered
           ? Qt.rgba(1, 1, 1, 0.20)
           : "transparent"

    Behavior on color { ColorAnimation { duration: 20 } }

    XCFile { id: elementFile }

    function normalizedPath(filePath) {
        if (filePath === undefined || filePath === null)
            return ""
        return String(filePath).trim()
                               .replace(/^file:\/\/\/?/, "")
                               .replace(/\\/g, "/")
    }

    function itemIdFromValue(value) {
        var text = value === undefined || value === null ? "" : String(value).trim()
        var match = text.match(/^([a-z0-9_.-]+(?::[a-z0-9_./-]+)?)/i)
        return match ? match[1] : ""
    }

    function storedItemIconSource() {
        if (!hasSelection)
            return ""

        var itemData
        try {
            itemData = JSON.parse(elementFile.read(selectedElementPath))
        } catch (error) {
            return defaultIconSource
        }

        var texturePath = Global.getItemTexturePath(itemIdFromValue(itemData ? itemData.item : ""))
        if (!texturePath.length || !elementFile.exists(texturePath))
            return defaultIconSource

        return "file:///" + texturePath.replace(/\\/g, "/")
    }

    function setElement(filePath, notifyChange) {
        var path = normalizedPath(filePath)
        if (!path.length) {
            clearElement(notifyChange)
            return
        }

        var actualType = Global.elementTypeFromPath(path)
        if (actualType.toLowerCase() !== "item")
            return

        var wasWaiting = waitingForSelection
        selectedElementPath = path
        waitingForSelection = false
        if (wasWaiting)
            SignalBus.elementSelectionFocusChanged(false, {})
        if (notifyChange === undefined || notifyChange)
            elementSelected(path)
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

    function setLit(value) {
        lit = value
        if (!lit && waitingForSelection)
            cancelElementSelection()
    }

    function light() {
        if (parent) {
            var siblings = parent.children
            for (var index = 0; index < siblings.length; ++index) {
                var sibling = siblings[index]
                if (sibling !== root && sibling.isItemSlot === true)
                    sibling.setLit(false)
            }
        }
        setLit(true)
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
        interval: 40
        repeat: true
        running: root.waitingForSelection
        onTriggered: root.updateFocusGeometry()
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

    Image {
        anchors.fill: parent
        anchors.margins: Math.max(2, Math.round(root.size * 0.08))
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: false
        mipmap: false
        visible: root.hasSelection && status === Image.Ready
    }

    MouseArea {
        id: slotMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: {
            if (!root.lit) {
                root.light()
                return
            }
            if (root.waitingForSelection)
                root.cancelElementSelection()
            else
                root.requestElementSelection()
        }
    }

    DropArea {
        anchors.fill: parent
        keys: ["xcshop-element"]
        onEntered: function(drag) {
            root.dropHovered = true
            drag.acceptProposedAction()
        }
        onExited: root.dropHovered = false
        onDropped: function(drop) {
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
