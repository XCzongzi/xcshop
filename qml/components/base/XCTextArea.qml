import QtQuick
import QtQuick.Controls
import xcshop

TextArea{
    id: root
    height: 32
    clip: true

    signal accepted
    property bool highlightMacros: false
    property var highlightRanges: []
    property int editorFontSize: 16

    wrapMode: TextEdit.WrapAnywhere
    textFormat: TextEdit.PlainText

    color: Colors.text
    selectionColor: Colors.selection
    selectedTextColor: Colors.isLight ? Colors.text : palette.highlightedText
    leftPadding: 10
    rightPadding: 10
    topPadding: 8
    bottomPadding: 8
    placeholderTextColor: Colors.changeA(Colors.placeholder, 0.78)

    background: InputBackground {
        focused: root.activeFocus
        idleOpacity: 0.50
    }

    font: EditorFonts.mixedFont(Global.editorChineseFont, Global.editorLatinFont, editorFontSize)

    EditorHighlighter {
        target: root
        ranges: root.highlightRanges
        highlightMacros: root.highlightMacros
        macroColor: Colors.error
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
