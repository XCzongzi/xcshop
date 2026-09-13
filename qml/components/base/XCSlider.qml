import QtQuick
import QtQuick.Controls
import xcshop

// A compact desktop-style range input.  It intentionally keeps the public
// API of QtQuick.Controls Slider, so it can replace a standard Slider without
// changing the surrounding value or signal bindings.
Slider {
    id: root

    property int trackHeight: 6
    property int handleDiameter: 18
    property color trackColor: Colors.changeA(Colors.background, 0.56)
    property color fillColor: Colors.changeA(Colors.border, enabled ? 0.94 : 0.38)
    property color handleColor: !enabled ? Colors.changeA(Colors.banned, 0.62)
                                         : (pressed ? Colors.border
                                                    : (hovered ? Colors.changeA(Colors.border, 0.96)
                                                               : Colors.changeA(Colors.border, 0.84)))

    implicitWidth: 200
    implicitHeight: 32
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    activeFocusOnTab: true

    background: Item {
        x: root.leftPadding + root.handleDiameter / 2
        y: root.topPadding + (root.availableHeight - height) / 2
        width: Math.max(0, root.availableWidth - root.handleDiameter)
        height: root.trackHeight

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.trackColor
            border.width: 1
            border.color: Colors.changeA(Colors.text, root.enabled ? 0.10 : 0.06)

            Behavior on color { ColorAnimation { duration: 130 / Global.animationSpeed } }
            Behavior on border.color { ColorAnimation { duration: 130 / Global.animationSpeed } }
        }

        Rectangle {
            width: Math.max(0, root.visualPosition * parent.width)
            height: parent.height
            radius: height / 2
            color: root.fillColor

            Behavior on width { NumberAnimation { duration: root.pressed ? 0 : 100 / Global.animationSpeed; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 130 / Global.animationSpeed } }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + (root.availableHeight - height) / 2
        width: root.handleDiameter
        height: width
        radius: width / 2
        color: root.handleColor
        border.width: 2
        border.color: Colors.changeA(Colors.background_n, root.enabled ? 0.58 : 0.28)
        scale: root.pressed ? 0.88 : (root.hovered ? 1.08 : 1.0)

        Behavior on color { ColorAnimation { duration: 130 / Global.animationSpeed } }
        Behavior on border.color { ColorAnimation { duration: 130 / Global.animationSpeed } }
        Behavior on scale { NumberAnimation { duration: 110 / Global.animationSpeed; easing.type: Easing.OutCubic } }
    }
}
