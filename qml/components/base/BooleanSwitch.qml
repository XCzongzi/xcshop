import QtQuick
import xcshop

// Compact boolean input used by text-style editors.
Rectangle {
    id: root

    property string label: ""
    property bool checked: false
    property bool hovered: false
    property bool pressed: false

    signal toggled(bool value)

    width: 28
    height: 28
    radius: 5
    color: checked ? Colors.changeA(Colors.border, 0.66) : Colors.changeA(Colors.pressed, 0.66)
    border.width: 1
    border.color: checked ? Colors.border : Colors.changeA(Colors.text, 0.12)

    Behavior on color { ColorAnimation { duration: 130 / Global.animationSpeed } }
    Behavior on border.color { ColorAnimation { duration: 130 / Global.animationSpeed } }

    XCText {
        anchors.centerIn: parent
        xcText: root.label
        xcFontSize: 11
        textColor: root.checked ? Colors.background_n : Colors.text
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
        onClicked: root.toggled(!root.checked)
    }
}
