pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    property int per_width: 200
    property int per_height: 32
    property var options: []
    property int selected: 0
    property bool opened: false
    property bool hovered: false
    property bool pressed: false

    signal clicked()

    width: per_width
    height: per_height

    Rectangle {
        id: head
        anchors.fill: parent
        radius: 8
        color: root.pressed ? Colors.changeA(Colors.pressed, 0.96)
                            : (root.hovered ? Colors.changeA(Colors.foreground, 0.94)
                                            : Colors.changeA(Colors.background, 0.56))
        border.width: 1
        border.color: root.opened || root.hovered ? Colors.changeA(Colors.border, 0.60)
                                                   : Colors.changeA(Colors.text, 0.10)

        Behavior on color { ColorAnimation { duration: 130 / Global.animationSpeed } }
        Behavior on border.color { ColorAnimation { duration: 130 / Global.animationSpeed } }

        XCText {
            x: 11
            width: parent.width - 34
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.options.length > root.selected ? root.options[root.selected] : "未选择"
            onCenter: false
            xcFontSize: 13
            boldFont: false
        }
        XCText {
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.opened ? "⌃" : "⌄"
            xcFontSize: 14
            textColor: Colors.banned
            boldFont: false
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hovered = true
            onExited: {
                root.hovered = false
                root.pressed = false
            }
            onPressed: root.pressed = true
            onReleased: root.pressed = false
            onClicked: root.opened = !root.opened
        }
    }

    Rectangle {
        id: body
        z: 10
        x: 0
        y: head.height + 6
        width: root.width
        height: root.opened ? optionColumn.height + 10 : 0
        radius: 10
        clip: true
        visible: root.opened
        color: Colors.changeA(Colors.foreground, 0.98)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.12)

        layer.enabled: true
        layer.effect: XCShadow { shadowVerticalOffset: 5; shadowHorizontalOffset: 0; shadowBlur: 0.65 }

        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: {} }

        Column {
            id: optionColumn
            x: 5
            y: 5
            width: parent.width - 10
            spacing: 2

            Repeater {
                model: root.options
                delegate: TextButton {
                    required property int index
                    required property var model
                    width: optionColumn.width
                    height: 30
                    radius: 6
                    text: model.modelData
                    textSize: 13
                    boldFont: false
                    widthBorderSize: 8
                    buttonColor: Colors.transparent
                    firedColor: Colors.changeA(Colors.fired, 0.38)
                    pressedColor: Colors.changeA(Colors.border, 0.58)
                    btnSelected: root.selected === index
                    allowSelectedClick: true
                    onClicked: {
                        root.selected = index
                        root.opened = false
                        root.clicked()
                    }
                }
            }
        }

        Behavior on height { NumberAnimation { duration: 160 / Global.animationSpeed; easing.type: Easing.OutCubic } }
    }
}
