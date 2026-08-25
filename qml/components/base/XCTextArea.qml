import QtQuick
import QtQuick.Controls



TextArea{
    id: root
    height: 32

    signal accepted()

    wrapMode: TextEdit.Wrap

    color: Colors.text
    selectionColor: Colors.fired
    leftPadding: 10
    rightPadding: 10
    topPadding: 8
    bottomPadding: 8
    placeholderTextColor: Colors.changeA(Colors.banned, 0.78)

    background: Rectangle {
        color: root.activeFocus ? Colors.changeA(Colors.background, 0.72)
                                : Colors.changeA(Colors.background, 0.50)
        radius: 7
        clip: true
        border.width: 1
        border.color: root.activeFocus ? Colors.changeA(Colors.border, 0.82)
                                       : Colors.changeA(Colors.text, 0.10)

        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }

        Rectangle{
            visible: root.activeFocus
            width: parent.width - 14
            height: 2
            x: 7
            y: parent.height - height - 3
            radius: 1
            color: Colors.border
        }
    }
    
    font.family: "微软雅黑"
    font.pixelSize: 16


    Keys.onPressed:event=>{
        if(event.key === Qt.Key_Return || event.key === Qt.Key_Enter){   //检测是否按下Enter
            if(event.modifiers & Qt.ControlModifier){   //检测是否同时按下Ctrl
                event.accepted = true
                root.accepted()         //Ctrl+Enter时提交
            }
        }
    }

}
