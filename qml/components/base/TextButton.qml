import QtQuick
import xcshop

Rectangle{
    id: root
    // 颜色完全由状态计算；不要在鼠标事件中直接修改 color，否则会破坏绑定。
    color: !enabled ? Colors.disabledSurface : buttonColor

    property string text:""
    property bool btnSelected: false
    // Navigation tabs keep their selected item inert; option lists can opt in
    // when selecting the current value should still close the menu.
    property bool allowSelectedClick: false
    property int widthBorderSize:0
    property int heightBorderSize:0
    property int textSize:12
    property bool boldFont: true
    property bool underlineFont: false

    property color buttonColor: Colors.transparent
    property color firedColor: Colors.fired
    property color pressedColor: Colors.pressed
    property color textColor: Colors.text
    property bool hovered: false
    property bool pressed: false
    property bool colorAnimationEnabled: true

    signal clicked()

    width:buttonText.width + widthBorderSize*2
    height:buttonText.height + heightBorderSize*2

    function setSelected(selected, noAnimation){
        colorAnimationEnabled = !noAnimation
        btnSelected = selected
        if (noAnimation)
            colorAnimationEnableTimer.start()
    }


    ButtonStateOverlay {
        hoverColor: root.firedColor
        pressedColor: root.pressedColor
        hovered: root.hovered
        pressed: root.pressed
        selected: root.btnSelected
        stateEnabled: root.enabled
        animationEnabled: root.colorAnimationEnabled
        duration: 200
        cornerRadius: root.radius
    }

    XCText{
        id: buttonText
        xcText: root.text
        textColor: root.textColor
        xcFontSize: root.textSize
        boldFont: root.boldFont
        underlineFont: root.underlineFont
    }

    Timer {
        id: colorAnimationEnableTimer
        interval: 1
        onTriggered: root.colorAnimationEnabled = true
    }

    MouseArea {
        id: mouseArea
        visible: root.enabled && (!root.btnSelected || root.allowSelectedClick)
        anchors.fill: parent
        propagateComposedEvents: true
        hoverEnabled: true
        onClicked: {
            focus = true
            root.clicked()
        }
        onEntered: root.hovered = true
        onExited: {
            root.hovered = false
            root.pressed = false
        }
        onPressed: {
            root.pressed = true
            forceActiveFocus()
        }
        onReleased: root.pressed = false
        
    }

}
