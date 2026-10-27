import QtQuick
import QtQuick.Controls
import xcshop

TextArea{
    id: root
    height: 32

    signal accepted
    property bool highlightMacros: false

    wrapMode: TextEdit.Wrap

    color: Colors.text
    selectionColor: Colors.fired
    leftPadding: 10
    rightPadding: 10
    topPadding: 8
    bottomPadding: 8
    placeholderTextColor: Colors.changeA(Colors.banned, 0.78)

    background: InputBackground {
        focused: root.activeFocus
        idleOpacity: 0.50
    }

    font.family: "微软雅黑"
    font.pixelSize: 16

    MacroTextOverlay {
        target: root
        highlightMacros: root.highlightMacros
    }

    Keys.onPressed:event=>{
        if(event.key === Qt.Key_Return || event.key === Qt.Key_Enter){   //检测是否按下Enter
            if(event.modifiers & Qt.ControlModifier){   //检测是否同时按下Ctrl
                event.accepted = true
                root.accepted()         //Ctrl+Enter时提交
            }
        }
    }

}
