import QtQuick
import xcshop

// A single-row variant of ElementSelection.  Its public API intentionally
// mirrors ElementSelection so it can be used in delegates without adapters.
Rectangle {
    id: root

    property string selectionId: ""
    property string selectedElementPath: ""
    property bool waitingForSelection: false
    property bool externalDragActive: false
    property bool dropHovered: false
    property string validationMessage: ""

    readonly property bool hasSelection: selectedElementPath.length > 0
    readonly property bool highlighted: waitingForSelection || externalDragActive || dropHovered
    readonly property string elementIconSource: {
        switch (selectionId.toLowerCase()) {
        case "ui": return "qrc:/assets/gui/element/UI.png"
        case "item": return "qrc:/assets/gui/element/Item.png"
        case "cost": return "qrc:/assets/gui/element/Cost.png"
        case "display": return "qrc:/assets/gui/element/Display.png"
        default: return "qrc:/assets/gui/element/File.png"
        }
    }
    readonly property string selectionTypeName: {
        switch (selectionId.toLowerCase()) {
        case "ui": return "界面元素"
        case "item": return "商品元素"
        case "cost": return "代价元素"
        case "display": return "展示元素"
        default: return "元素"
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
    signal selectionCleared()


    width: 380
    height: 44
    radius: 8
    color: highlighted ? Colors.changeA(Colors.border, 0.12)
                       : Colors.changeA(Colors.background, 0.30)
    border.width: 1
    border.color: highlighted ? Colors.changeA(Colors.border, 0.82)
                              : Colors.changeA(Colors.text, 0.11)

    Behavior on border.color { ColorAnimation { duration: 160 } }
    Behavior on color { ColorAnimation { duration: 160 } }

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
        if (!element || (selectionId.length
                         && element.type.toLowerCase() !== selectionId.toLowerCase())) {
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

    Item {
        id: typeSummary
        visible: root.width >= 250
        x: 7
        width: typeIcon.width + 7 + typeText.width + 10
        height: parent.height

        Image {
            id: typeIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            source: root.elementIconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
        }

        XCText {
            id: typeText
            anchors.left: typeIcon.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.selectionTypeName
            xcFontSize: 11
            boldFont: false
            textColor: Colors.text
        }
    }

    Rectangle {
        id: typeSeparator
        visible: typeSummary.visible
        anchors.left: typeSummary.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Colors.changeA(Colors.text, 0.14)
    }

    Item {
        id: selectionSummary
        anchors.left: typeSeparator.visible ? typeSeparator.right : parent.left
        anchors.leftMargin: 9
        anchors.right: selectButton.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        XCText {
            id: placeholder
            visible: !root.hasSelection
            width: Math.min(implicitWidth, parent.width)
            xcText: root.placeholderText
            xcFontSize: 12
            boldFont: false
            onCenter: false
            onVCenter: true
            textColor: root.highlighted ? Colors.changeA(Colors.border, 0.92) : Colors.banned
        }

        XCText {
            id: selectedName
            visible: root.hasSelection
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.max(72, parent.width * 0.42))
            xcText: root.selectedElementName
            xcFontSize: 12
            onCenter: false
            textColor: Colors.text
        }

        XCText {
            id: pathSeparator
            visible: root.hasSelection
            anchors.left: selectedName.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            xcText: "|"
            xcFontSize: 12
            boldFont: false
            onCenter: false
            textColor: Colors.changeA(Colors.text, 0.35)
        }

        XCText {
            visible: root.hasSelection
            anchors.left: pathSeparator.right
            anchors.leftMargin: 7
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.selectedElementDisplayPath
            xcFontSize: 11
            boldFont: false
            onCenter: false
            elide: Text.ElideLeft
            textColor: Colors.banned
        }
    }

    TextButton {
        id: selectButton
        anchors.right: clearButton.visible ? clearButton.left : parent.right
        anchors.rightMargin: clearButton.visible ? 5 : 7
        anchors.verticalCenter: parent.verticalCenter
        width: root.waitingForSelection ? 56 : 50
        height: 28
        radius: 6
        text: root.waitingForSelection ? "取消" : "选择"
        textSize: 11
        boldFont: false
        buttonColor: Colors.changeA(Colors.border, 0.68)
        firedColor: Colors.changeA(Colors.border, 0.88)
        pressedColor: Colors.changeA(Colors.border, 0.50)
        onClicked: {
            if (root.waitingForSelection)
                root.cancelElementSelection()
            else
                root.requestElementSelection()
        }
    }

    TextButton {
        id: clearButton
        visible: root.hasSelection
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 6
        text: "×"
        textSize: 17
        boldFont: false
        textColor: Colors.banned
        buttonColor: Colors.changeA(Colors.text, 0.035)
        firedColor: Colors.changeA(Colors.error, 0.18)
        pressedColor: Colors.changeA(Colors.error, 0.28)
        onClicked: root.clearElement(true)
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
