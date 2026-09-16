import QtQuick
import QtQuick.Controls
import xcshop



TextField{
    id: root
    height: 32

    property bool isWrap: false // 默认为非自动换行
    wrapMode: isWrap? TextEdit.Wrap : TextEdit.NoWrap // 自动换行((No)Warp)
    property bool highlightMacros: false
    verticalAlignment: isWrap? TextInput.AlignTop : TextInput.AlignVCenter

    color: Colors.text
    selectionColor: Colors.fired
    autoScroll: true
    leftPadding: 10
    rightPadding: 10
    topPadding: root.isWrap ? 8 : 0
    bottomPadding: root.isWrap ? 8 : 0
    placeholderTextColor: Colors.changeA(Colors.banned, 0.78)

    background: Rectangle {
        color: root.activeFocus ? Colors.changeA(Colors.background, 0.72)
                                : Colors.changeA(Colors.background, root.isWrap ? 0.50 : 0.36)
        radius: 7
        clip: true
        border.width: 1
        border.color: root.activeFocus ? Colors.changeA(Colors.border, 0.82)
                                       : Colors.changeA(Colors.text, 0.10)

        Behavior on color { ColorAnimation { duration: 130 / Global.animationSpeed } }
        Behavior on border.color { ColorAnimation { duration: 130 / Global.animationSpeed } }

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
    
    font.family: "Consolas"
    font.pixelSize: 16

    MacroTextOverlay {
        target: root
        highlightMacros: root.highlightMacros
    }

}
