import QtQuick
import xcshop

// Desktop-style checkbox for selecting one or more independent items.
Item {
    id: root

    property string text: ""
    property bool checked: false
    property bool hovered: false
    property bool pressed: false
    property int textSize: 13
    property bool boldFont: false
    property color textColor: enabled ? Colors.text : Colors.banned

    signal toggled(bool checked)

    readonly property int indicatorSize: 18
    readonly property int contentWidth: indicatorSize + (text.length ? 8 + label.implicitWidth : 0)

    implicitWidth: contentWidth
    implicitHeight: Math.max(indicatorSize, label.implicitHeight)
    width: implicitWidth
    height: implicitHeight
    activeFocusOnTab: true

    function toggle() {
        if (!enabled)
            return

        checked = !checked
        toggled(checked)
    }

    onCheckedChanged: checkMark.requestPaint()

    Rectangle {
        id: indicator
        width: root.indicatorSize
        height: root.indicatorSize
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        radius: 5
        color: root.checked ? Colors.changeA(Colors.border, root.pressed ? 0.72 : 0.90)
                            : Colors.changeA(Colors.background, root.hovered ? 0.70 : 0.48)
        border.width: 1
        border.color: root.checked ? Colors.changeA(Colors.border, 0.95)
                                   : Colors.changeA(Colors.text, root.hovered ? 0.32 : 0.16)

        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }

        Canvas {
            id: checkMark
            anchors.fill: parent
            visible: root.checked
            opacity: visible ? 1 : 0

            onPaint: {
                var context = getContext("2d")
                context.reset()
                context.clearRect(0, 0, width, height)
                context.strokeStyle = Colors.background_n
                context.lineWidth = 2
                context.lineCap = "round"
                context.lineJoin = "round"
                context.beginPath()
                context.moveTo(width * 0.25, height * 0.53)
                context.lineTo(width * 0.43, height * 0.70)
                context.lineTo(width * 0.76, height * 0.32)
                context.stroke()
            }

            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }

    XCText {
        id: label
        visible: root.text.length > 0
        anchors.left: indicator.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        xcText: root.text
        xcFontSize: root.textSize
        boldFont: root.boldFont
        onCenter: false
        textColor: root.textColor
    }

    Keys.onSpacePressed: function(event) {
        root.toggle()
        event.accepted = true
    }
    Keys.onReturnPressed: function(event) {
        root.toggle()
        event.accepted = true
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: {
            root.hovered = false
            root.pressed = false
        }
        onPressed: {
            root.pressed = true
            root.forceActiveFocus()
        }
        onReleased: root.pressed = false
        onClicked: root.toggle()
    }
}
