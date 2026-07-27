import QtQuick
import xcshop

Rectangle{
    id: root
    //width: 100
    //height: 24
    color: Colors.transparent

    property string text
    property bool btnSelected: false
    property string icon

    property int imgSize: 18

    signal clicked()

    property double borderOpacity: root.activeFocus? 1 : 0
        border.color: Colors.changeA(Colors.border,borderOpacity)
        border.width: 1
        Behavior on borderOpacity{
            enabled: !root.activeFocus
            NumberAnimation{
                duration: 300
            }
        }

    function setSelection(selected,noAnimation){
        imgAnim.enabled = !noAnimation
        colorAnim.duration = noAnimation? 0 : 200
        root.btnSelected = selected
        root.imgSize = selected? 24 : 18
        timer.start()
    }
    Timer{      //选中后禁用MouseArea时，仍会触发槽函数导致颜色设置被替代，因此用Timer来延迟颜色设置
        id: timer
        interval: 1
        onTriggered:{
            colorAnim.start()
        }
    }
    ColorAnimation{
        id: colorAnim
        target: root
        property: "color"
        duration: 200
        to: root.btnSelected? Colors.banned : Colors.transparent
    }

    Image {
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        id: img
        source: "qrc:/assets/gui/element/" + root.icon + ".png"
        sourceSize.width: root.imgSize
        sourceSize.height: root.imgSize
    }
    XCText{
        id: fileText
        x: 32
        width: parent.width - 32
        xcText: root.text
        xcFontSize: 12
    }
    // Text {
    //     id: fileText
    //     x: 32
    //     width: parent.width - 32
    //     anchors.verticalCenter: parent.verticalCenter
    //     text: qsTr(root.text)
    //     elide: Text.ElideRight
    //     color: Colors.text
    //     font.pixelSize: 12
    //     font.family: "微软雅黑"
    //     font.bold: true
    // }

    Behavior on imgSize{
        id: imgAnim
        NumberAnimation{
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    MouseArea {
        visible: !root.btnSelected
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        onEntered: {
            parent.color = Colors.fired
            root.imgSize = 24
        }
        onExited: {
            parent.color = Colors.transparent
            root.imgSize = 18
        }
        onPressed: {
            parent.color = Colors.pressed
            root.imgSize = 15
            root.forceActiveFocus()
        }
        onReleased: {
            if (containsMouse) {
                parent.color = Colors.fired
                root.imgSize = 24
            }else{
                parent.color = Colors.transparent
                root.imgSize = 18
            }
        }
    }
}