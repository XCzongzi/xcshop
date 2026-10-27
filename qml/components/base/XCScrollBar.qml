import QtQuick
import QtQuick.Controls as Controls
import xcshop

Controls.ScrollBar {
    id: root
    policy: Controls.ScrollBar.AsNeeded
    visible: policy === Controls.ScrollBar.AlwaysOn || (policy === Controls.ScrollBar.AsNeeded && size < 1)
    minimumSize: height > 0 ? Math.min(1, 30 / height) : 1
    padding: 0
    contentItem: Rectangle {
        implicitWidth: 8
        implicitHeight: 8
        radius: 3
        color: root.pressed ? Colors.border : Colors.changeA(Colors.banned, root.hovered ? 0.8 : 0.45)
        Behavior on color {
            ColorAnimation {
                duration: 130 / Global.animationSpeed
            }
        }
    }
    background: Item {
        implicitWidth: 8
        implicitHeight: 8
    }
}
