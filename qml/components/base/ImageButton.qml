import QtQuick
import QtQuick.Controls.impl as Impl
import xcshop

Rectangle {
    id: root

    property alias imageSource: img.source
    property bool tintIcon: true
    property color imageColor: btnbackground.a > 0
            ? Colors.contrastingText(Qt.tint(Colors.card, pressed ? btnpressed : hovered ? btnfired : btnbackground))
            : Colors.text
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

    // 保留旧接口；选中状态由 btnSelected 统一驱动。
    function setColor() {}

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

    Impl.IconImage {
        id: img
        anchors.centerIn: parent
        sourceSize.width: root.btnSelected ? root.imgSize - 3 : root.imgSize_
        sourceSize.height: root.btnSelected ? root.imgSize - 3 : root.imgSize_
        color: root.tintIcon && Colors.isLight ? root.imageColor : Colors.transparent
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
