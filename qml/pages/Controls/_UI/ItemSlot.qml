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
    property bool nestedPreviewed: false
    property bool nestedOccupied: false
    property bool nestingDrawMode: false
    property bool controlHovered: false

    readonly property bool isItemSlot: true
    readonly property bool hasSelection: selectedElementPath.length > 0
    readonly property string defaultIconSource: "qrc:/assets/gui/element/Item.png"
    readonly property string iconSource: storedItemIconSource()
    property int iconRevision: 0
    readonly property string selectedElementName: {
        var element = Global.parseElementPath(selectedElementPath)
        if (element)
            return element.name
        var parts = normalizedPath(selectedElementPath).split("/")
        return parts.length ? parts[parts.length - 1] : ""
    }
    readonly property string selectedElementDisplayPath: {
        var element = Global.parseElementPath(selectedElementPath)
        return element ? element.relativePath : normalizedPath(selectedElementPath)
    }

    signal selectionRequested(string selectionId)
    signal selectionCancelled(string selectionId)
    signal elementSelected(string filePath)
    signal selectionCleared()
    signal activated()
    signal nestedSlotToggled()

    width: size
    height: size
    radius: 0
    z: itemTooltip.visible ? 1000 : 0
    color: nestedPreviewed ? Colors.changeA(Colors.border, 0.28)
                           : (lit || slotMouse.containsMouse || dropHovered
                              ? Qt.rgba(1, 1, 1, 0.56)
                              : "transparent")

    Behavior on color { ColorAnimation { duration: 20 / Global.animationSpeed } }

    onNestingDrawModeChanged: {
        if (nestingDrawMode && waitingForSelection)
            cancelElementSelection()
    }

    XCFile { id: elementFile }

    function normalizedPath(filePath) {
        return Global.resolveElementPath(filePath)
    }

    function itemIdFromValue(value) {
        var text = value === undefined || value === null ? "" : String(value).trim()
        var match = text.match(/^([a-z0-9_.-]+(?::[a-z0-9_./-]+)?)/i)
        return match ? match[1] : ""
    }

    function storedItemIconSource() {
        // Item 文件保存后即使引用路径未变，也要重新读取固定的 item 属性。
        var revision = iconRevision
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

        var element = Global.parseElementPath(path)
        if (!element || element.type.toLowerCase() !== "item")
            return
        path = element.path

        var wasWaiting = waitingForSelection
        selectedElementPath = path
        waitingForSelection = false
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

    Keys.enabled: slotMouse.containsMouse
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Control)
            root.controlHovered = root.hasSelection && !root.nestingDrawMode
        event.accepted = false
    }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Control)
            root.controlHovered = false
        event.accepted = false
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

        function onElementDataSaved(savedType, savedPath) {
            if (savedType === "Item"
                    && Global.normalizeElementPath(savedPath)
                       === Global.normalizeElementPath(root.selectedElementPath))
                root.iconRevision++
        }

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
        id: slotIcon
        anchors.fill: parent
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: false
        mipmap: false
        visible: root.hasSelection && status === Image.Ready
        opacity: root.nestingDrawMode ? 0.42 : 1

        Behavior on opacity { NumberAnimation { duration: 120 / Global.animationSpeed } }
    }

    Rectangle {
        anchors.fill: parent
        z: 1
        visible: root.nestedOccupied && !root.nestedPreviewed
        color: Qt.rgba(0.18, 0.19, 0.22, 0.42)
        border.width: 1
        border.color: Qt.rgba(0.10, 0.11, 0.13, 0.58)
    }

    Item {
        id: itemTooltip
        visible: root.hasSelection && slotMouse.containsMouse && !root.nestingDrawMode
        z: 2
        width: tooltipContent.implicitWidth + 32
        height: tooltipContent.implicitHeight + 26
        x: slotMouse.mouseX + 12
        y: slotMouse.mouseY - height / 2

        BorderImage {
            anchors.fill: parent
            source: "qrc:/assets/minecraft/gui/item_lore/background.png"
            border.left: 10
            border.top: 10
            border.right: 10
            border.bottom: 10
            horizontalTileMode: BorderImage.Stretch
            verticalTileMode: BorderImage.Stretch
        }

        BorderImage {
            anchors.fill: parent
            source: "qrc:/assets/minecraft/gui/item_lore/frame.png"
            border.left: 10
            border.top: 10
            border.right: 10
            border.bottom: 10
            horizontalTileMode: BorderImage.Stretch
            verticalTileMode: BorderImage.Stretch
        }

        BorderImage {
            anchors.fill: parent
            anchors.margins: 1
            source: "qrc:/assets/minecraft/gui/item_lore/frame.png"
            border.left: 10
            border.top: 10
            border.right: 10
            border.bottom: 10
            horizontalTileMode: BorderImage.Stretch
            verticalTileMode: BorderImage.Stretch
        }

        Row {
            id: tooltipContent
            anchors.centerIn: parent
            spacing: 0

            Text {
                text: root.selectedElementName
                color: root.controlHovered ? Colors.border : "white"
                font.family: "Microsoft YaHei"
                font.pixelSize: 16
                font.underline: root.controlHovered
            }
            Text {
                text: " | " + root.selectedElementDisplayPath
                color: "#a0a0a0"
                font.family: "Microsoft YaHei"
                font.pixelSize: 16
            }
        }
    }

    MouseArea {
        id: slotMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.hasSelection && root.controlHovered && !root.nestingDrawMode
                     ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: root.forceActiveFocus()
        onPressed: root.forceActiveFocus()
        onPositionChanged: function(mouse) {
            root.controlHovered = (mouse.modifiers & Qt.ControlModifier) !== 0
        }
        onExited: root.controlHovered = false
        onClicked: function(mouse) {
            if (root.nestingDrawMode) {
                root.nestedSlotToggled()
                return
            }
            if ((mouse.modifiers & Qt.ControlModifier) && root.hasSelection) {
                root.openConnectedElement()
                return
            }
            if (!root.lit) {
                root.light()
                root.activated()
                return
            }
            root.activated()
            if (root.waitingForSelection)
                root.cancelElementSelection()
            else
                root.requestElementSelection()
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !root.nestingDrawMode
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
