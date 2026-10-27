import QtQuick
import xcshop

Rectangle{
    id: root
    color: Colors.card
    height: 36
    width: text.x + text.width + 16
    radius: 8
    border.width: 1
    border.color: Colors.glass_highlight

    property string text
    property string icon
    property bool hovered: false
    property bool pressed: false

    signal clicked()

    layer.enabled: true
    layer.effect:XCShadow{}
    ButtonStateOverlay {
        hoverColor: Colors.fired
        pressedColor: Colors.pressed
        hovered: root.hovered
        pressed: root.pressed
        stateEnabled: root.enabled
        duration: 120
        cornerRadius: root.radius
    }
    LightEffect{
        lightSource_r: 18
        lightSource_x:mouseArea.mouseX
        lightSource_y:mouseArea.mouseY
        blur: 0.8
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        onEntered: root.hovered = true
        onExited: { root.hovered = false; root.pressed = false }
        onPressed: { root.pressed = true; forceActiveFocus() }
        onReleased: root.pressed = false
    }

    ThemedIcon {
        id:img
        iconSource: root.icon
        height: root.height - 16
        width: height
        x: 16
        y: 8
        smooth: true
        antialiasing: true
        mipmap: true
    }
    XCText{
        id:text
        x: img.x + img.width + 8
        xcFontSize: img.height - 2
        text: root.text
        boldFont: false
    }
}
