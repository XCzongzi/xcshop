import QtQuick
import xcshop

Rectangle {
    id: root
    property alias imageSource: img.source
    property int btnSize: 32    //按钮大小
    property int imgSize: 30     //图像大小，用于动画
    property color btnbackground: Colors.transparent
    property color btnfired: Colors.fired
    property color btnpressed: Colors.pressed
    property int btnRadius: 3
    property bool btnSelected: false
    property bool freeze: false
    signal clicked()
    

    function setColor(){    //选中后调用此函数以固定颜色
        color = Colors.pressed
    }
    
    width: btnSize
    height: btnSize
    color: btnSelected? btnpressed : btnbackground
    radius: btnRadius

    property int imgSize_: imgSize

    Image {
        id: img
        anchors.centerIn: parent
        sourceSize.width: root.btnSelected? (root.imgSize-3) : root.imgSize_
        sourceSize.height: root.btnSelected? (root.imgSize-3) : root.imgSize_
    }

    Behavior on color {
        ColorAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on imgSize_ {
        NumberAnimation {
            duration: 50
            easing.type: Easing.InOutQuad
        }
    }

    onBtnSelectedChanged: root.color = root.btnSelected? root.btnpressed : root.btnbackground

    MouseArea {
        visible: !root.btnSelected && !root.freeze
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        onPositionChanged: {
            parent.color = root.btnfired
            root.imgSize_ = root.imgSize + 6
        }
        onExited: {
            parent.color = root.btnbackground
            root.imgSize_ = root.imgSize
        }
        onPressed: {
            parent.color = root.btnpressed
            root.imgSize_ = root.imgSize - 6
            forceActiveFocus()
        }
        onReleased: {
            if (containsMouse) {
                parent.color = root.btnfired
                root.imgSize_ = root.imgSize + 6
            }else{
                parent.color = root.btnbackground
                root.imgSize_ = root.imgSize
            }
            
        }
    }
}
