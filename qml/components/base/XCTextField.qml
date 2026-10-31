import QtQuick
import QtQuick.Controls
import xcshop

TextField{
    id: root
    height: 32
    clip: true

    property bool isWrap: false // 默认为非自动换行
    wrapMode: isWrap ? TextInput.WrapAnywhere : TextInput.NoWrap
    property bool highlightMacros: false
    property var highlightRanges: []
    property int editorFontSize: 16
    verticalAlignment: isWrap? TextInput.AlignTop : TextInput.AlignVCenter

    color: Colors.text
    selectionColor: Colors.selection
    selectedTextColor: Colors.isLight ? Colors.text : palette.highlightedText
    autoScroll: true
    leftPadding: 10
    rightPadding: 10
    topPadding: root.isWrap ? 8 : 0
    bottomPadding: root.isWrap ? 8 : 0
    placeholderTextColor: Colors.changeA(Colors.placeholder, 0.78)

    background: InputBackground {
        focused: root.activeFocus
        idleOpacity: root.isWrap ? 0.50 : 0.36
    }

    font: EditorFonts.mixedFont(Global.editorChineseFont, Global.editorLatinFont, editorFontSize)

    EditorHighlighter {
        target: root
        ranges: root.highlightRanges
        highlightMacros: root.highlightMacros
        macroColor: Colors.error
    }

}
