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

    background: InputBackground {
        focused: root.activeFocus
        idleOpacity: root.isWrap ? 0.50 : 0.36
    }

    font.family: "Consolas"
    font.pixelSize: 16

    MacroTextOverlay {
        target: root
        highlightMacros: root.highlightMacros
    }

}
