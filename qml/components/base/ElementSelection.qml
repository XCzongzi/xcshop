import QtQuick
import xcshop

ElementSelectionBase {
    id: root
    width: parent ? Math.min(420, parent.width - 32) : 380
    height: 224
    radius: 12
    dropTarget: dropZone

    // ===== 顶栏：标题、状态与选择操作 =====
    XCText {
        x: 16
        y: 14
        xcText: "选择元素 · " + root.selectionTypeName
        xcFontSize: 16
        onCenter: false
    }

    // ===== 发起或取消中转区选择 =====
    ActionButton {
        id: selectButton
        primary: true
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
        onClicked: {
            if (root.waitingForSelection)
                root.cancelElementSelection()
            else
                root.requestElementSelection()
        }
    }

    // ===== 拖放目标与已选元素摘要 =====
    Rectangle {
        id: dropZone
        x: 14
        y: 54
        width: parent.width - 28
        height: 126
        radius: 10
        color: root.highlighted ? Colors.changeA(Colors.border, 0.09)
                                : Colors.changeA(Colors.input, 0.24)

        Behavior on color { ColorAnimation { duration: 160 / Global.animationSpeed } }

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

        ThemedIcon {
            id: elementMark
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 46
            iconSource: root.elementIconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
        }

        Column {
            id: selectionSummary
            anchors.left: elementMark.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            XCText {
                id: selectedName
                width: parent.width
                xcText: root.hasSelection ? root.selectedElementName
                                          : (root.waitingForSelection ? "请在元素中转区选择一个" + root.selectionTypeName
                                                                      : "尚未连接" + root.selectionTypeName)
                xcFontSize: 14
                onCenter: false
                underlineFont: root.hasSelection && root.connectedElementHovered
                textColor: root.hasSelection && root.connectedElementHovered
                           ? Colors.accentText : Colors.text
            }
            XCText {
                id: selectedPath
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
                underlineFont: root.hasSelection && root.connectedElementHovered
                textColor: root.hasSelection && root.connectedElementHovered
                           ? Colors.changeA(Colors.accentText, 0.86)
                           : (root.highlighted ? Colors.changeA(Colors.accentText, 0.86) : Colors.banned)
            }

            HoverHandler {
                id: selectedElementHover
                enabled: root.hasSelection
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: root.connectedElementHovered = hovered
            }

            TapHandler {
                enabled: root.hasSelection
                acceptedButtons: Qt.LeftButton
                onTapped: root.openConnectedElement()
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
}
