import QtQuick
import xcshop

Rectangle{
    id: root
    // 颜色完全由状态计算；不要在鼠标事件中直接修改 color，否则会破坏绑定。
    color: !enabled ? Colors.banned
                    : (btnSelected || pressed ? pressedColor
                                              : (hovered ? firedColor : buttonColor))

    property string text:""
    property bool btnSelected: false
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

    signal clicked()

    width:buttonText.width + widthBorderSize*2
    height:buttonText.height + heightBorderSize*2

    // 保留旧接口以兼容现有调用；选中状态才是唯一的状态来源。
    function setColor(){ btnSelected = true }
    function setColor_banned(){}


    XCText{
        id: buttonText
        xcText: root.text
        textColor: root.textColor
        xcFontSize: root.textSize
        boldFont: root.boldFont
        underlineFont: root.underlineFont
    }

    Behavior on color{
        ColorAnimation{
            duration: 200
        }
    }

    MouseArea {
        id: mouseArea
        visible: !root.btnSelected && root.enabled
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
