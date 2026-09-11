import QtQuick
import xcshop

Rectangle {
    id: root

    // ===== 对外状态与事件 =====
    // selectionId 当前表示允许接收的元素类型，而非组件实例的唯一 ID。
    property string selectionId: ""
    property string selectedElementPath: ""
    property bool waitingForSelection: false
    property bool externalDragActive: false
    property bool dropHovered: false
    property string validationMessage: ""

    // ===== 派生展示状态 =====
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

    signal selectionRequested(string selectionId)
    signal selectionCancelled(string selectionId)
    signal elementSelected(string filePath)
    signal selectionCleared()

    width: parent ? Math.min(420, parent.width - 32) : 380
    height: 224
    radius: 12
    color: Colors.changeA(Colors.background, 0.30)
    border.width: 1
    border.color: highlighted ? Colors.changeA(Colors.border, 0.82)
                              : Colors.changeA(Colors.text, 0.11)

    Behavior on border.color { ColorAnimation { duration: 160 } }
    Behavior on color { ColorAnimation { duration: 160 } }

    // ===== 路径校验与本地状态变更 =====
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
    Connections{    //连接遮罩的交互
        target: SignalBus
        function onElementSelectionDeselect(){
            root.cancelElementSelection()
        }
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

    // ===== 临时反馈与选择区域定位 =====
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

    // ===== SignalBus 事件接收 =====
    Connections {
        target: SignalBus

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

    // ===== 顶栏：标题、状态与选择操作 =====
    XCText {
        x: 16
        y: 14
        xcText: "选择元素 · " + root.selectionTypeName
        xcFontSize: 16
        onCenter: false
    }

    // ===== 发起或取消中转区选择 =====
    TextButton {
        id: selectButton
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 11
        height: 32
        width: 112
        radius: 8
        text: root.waitingForSelection ? "取消选择"
                                      : (root.hasSelection ? "重新选择" : "从中转区选择")
        textSize: 12
        boldFont: false
        buttonColor: Colors.changeA(Colors.border, 0.72)
        firedColor: Colors.changeA(Colors.border, 0.90)
        pressedColor: Colors.changeA(Colors.border, .5)
        onClicked: {
            if (root.waitingForSelection)
                root.cancelElementSelection()
            else
                root.requestElementSelection()
        }
    }

    // ===== 拖放目标与已选元素摘要 =====
    Rectangle {
        id: dropTarget
        x: 14
        y: 54
        width: parent.width - 28
        height: 126
        radius: 10
        color: root.highlighted ? Colors.changeA(Colors.border, 0.09)
                                : Colors.changeA(Colors.background, 0.24)

        Behavior on color { ColorAnimation { duration: 160 } }

        Canvas {    //虚线边框绘制
            id: dashedBorder
            anchors.fill: parent
            property color strokeColor: root.highlighted ? Colors.border
                                                         : Colors.changeA(Colors.text, 0.26)

            onStrokeColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = strokeColor
                ctx.lineWidth = root.highlighted ? 1.7 : 1.2
                ctx.setLineDash([7, 5])
                var inset = 1.5
                var radius = 9
                ctx.beginPath()
                ctx.moveTo(inset + radius, inset)
                ctx.lineTo(width - inset - radius, inset)
                ctx.quadraticCurveTo(width - inset, inset, width - inset, inset + radius)
                ctx.lineTo(width - inset, height - inset - radius)
                ctx.quadraticCurveTo(width - inset, height - inset, width - inset - radius, height - inset)
                ctx.lineTo(inset + radius, height - inset)
                ctx.quadraticCurveTo(inset, height - inset, inset, height - inset - radius)
                ctx.lineTo(inset, inset + radius)
                ctx.quadraticCurveTo(inset, inset, inset + radius, inset)
                ctx.stroke()
            }
        }

        Image {
            id: elementMark
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 46
            source: root.elementIconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
        }

        Column {
            anchors.left: elementMark.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            XCText {
                width: parent.width
                xcText: root.hasSelection ? root.selectedElementName
                                          : (root.waitingForSelection ? "请在元素中转区选择一个" + root.selectionTypeName
                                                                      : "尚未连接" + root.selectionTypeName)
                xcFontSize: 14
                onCenter: false
            }
            XCText {
                width: parent.width
                xcText: root.hasSelection ? root.selectedElementDisplayPath
                                          : (root.validationMessage.length ? root.validationMessage
                                             : (root.externalDragActive || root.dropHovered
                                             ? "松开鼠标即可连接此" + root.selectionTypeName
                                             : "可从元素中转区选择，或将元素拖放到此处"))
                xcFontSize: 11
                boldFont: false
                onCenter: false
                elide: Text.ElideLeft
                textColor: root.highlighted ? Colors.changeA(Colors.border, 0.86) : Colors.banned
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
    }


    // ===== 清除当前连接 =====
    TextButton {
        visible: root.hasSelection
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 190
        width: 72
        height: 26
        radius: 7
        text: "清除连接"
        textSize: 11
        boldFont: false
        textColor: Colors.banned
        buttonColor: Colors.changeA(Colors.text, 0.035)
        firedColor: Colors.changeA(Colors.error, 0.18)
        pressedColor: Colors.changeA(Colors.error, 0.28)
        onClicked: root.clearElement(true)
    }

    // ===== 生命周期清理 =====
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
