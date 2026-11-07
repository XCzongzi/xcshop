import QtQuick
import xcshop

Rectangle {
    id: root

    property alias imageSource: img.iconSource
    property bool tintIcon: true
    property color imageColor: Colors.text
    property int btnSize: 32
    property int imgSize: 30
    property color btnbackground: Colors.transparent
    property color btnfired: Colors.fired
    property color btnpressed: Colors.pressed
    property int btnRadius: 3
    property bool btnSelected: false
    property bool freeze: false
    property bool pressed: false
    property int imgSize_: imgSize
    readonly property bool hovered : hoverHandler.hovered

    signal clicked()


    width: btnSize
    height: btnSize
    color: btnbackground
    radius: btnRadius

    ButtonStateOverlay {
        hoverColor: root.btnfired
        pressedColor: root.btnpressed
        hovered: root.hovered
        pressed: root.pressed
        selected: root.btnSelected
        stateEnabled: root.enabled
        duration: 200
        cornerRadius: root.radius
        topRightRadius: root.topRightRadius
    }

    ThemedIcon {
        id: img
        anchors.centerIn: parent
        sourceSize.width: root.btnSelected ? root.imgSize - 3 : root.imgSize_
        sourceSize.height: root.btnSelected ? root.imgSize - 3 : root.imgSize_
        tintIcon: root.tintIcon
        tintColor: root.imageColor
    }

    Behavior on imgSize_ {
        NumberAnimation { duration: 50 / Global.animationSpeed; easing.type: Easing.InOutQuad }
    }

    HoverHandler{
        id: hoverHandler
    }
    MouseArea {
        visible: !root.btnSelected && !root.freeze && root.enabled
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        onEntered: {
            root.imgSize_ = root.imgSize + 6
        }
        onExited: {
            root.pressed = false
            root.imgSize_ = root.imgSize
        }
        onPressed: {
            root.pressed = true
            root.imgSize_ = root.imgSize - 6
            forceActiveFocus()
        }
        onReleased: {
            root.pressed = false
            root.imgSize_ = containsMouse ? root.imgSize + 6 : root.imgSize
        }
    }
}
