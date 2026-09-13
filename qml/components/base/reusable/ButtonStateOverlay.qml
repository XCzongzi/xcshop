import QtQuick
import xcshop

Item {
    id: root

    property color hoverColor: "transparent"
    property color pressedColor: hoverColor
    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool stateEnabled: true
    property bool animationEnabled: true
    property int duration: 160
    property real cornerRadius: 0
    property real topRightRadius: cornerRadius

    anchors.fill: parent
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        topRightRadius: root.topRightRadius
        color: root.hoverColor
        opacity: root.stateEnabled && root.hovered && !root.pressed && !root.selected ? 1 : 0

        Behavior on opacity {
            enabled: root.animationEnabled
            NumberAnimation { duration: root.duration / Global.animationSpeed; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        topRightRadius: root.topRightRadius
        color: root.pressedColor
        opacity: root.stateEnabled && (root.pressed || root.selected) ? 1 : 0

        Behavior on opacity {
            enabled: root.animationEnabled
            NumberAnimation { duration: root.duration / Global.animationSpeed; easing.type: Easing.OutCubic }
        }
    }
}
