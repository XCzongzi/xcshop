import QtQuick
import xcshop

Rectangle {
    id: root
    property bool focused: false
    property real idleOpacity: 0.36
    color: Colors.changeA(Colors.background, focused ? 0.72 : idleOpacity)
    radius: 7
    clip: true
    border.width: 1
    border.color: focused ? Colors.changeA(Colors.border, 0.82) : Colors.changeA(Colors.text, 0.10)
    Behavior on color {
        ColorAnimation {
            duration: 130 / Global.animationSpeed
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: 130 / Global.animationSpeed
        }
    }

    Rectangle {
        visible: root.focused
        x: 7
        y: parent.height - height - 3
        width: Math.max(0, parent.width - 14)
        height: 2
        radius: 1
        color: Colors.border
    }
}
