import QtQuick
import xcshop
import "../../../js/syntax/MacroHighlighter.js" as MacroHighlighter

Text {
    id: root

    property var target: null
    property bool highlightMacros: false
    property color macroColor: Colors.error
    readonly property bool multiline: target && (target.isWrap === undefined
                                                  || target.isWrap)

    visible: highlightMacros && target && target.text.length > 0
    z: 2
    x: target ? target.leftPadding : 0
    y: multiline
       ? target.topPadding
       : (target ? (target.height - height) / 2 : 0)
    width: target ? target.width - target.leftPadding - target.rightPadding : 0
    height: multiline
            ? target.height - target.topPadding - target.bottomPadding
            : implicitHeight
    clip: true
    text: MacroHighlighter.highlight(target ? target.text : "", macroColor)
    textFormat: Text.RichText
    wrapMode: multiline ? Text.WrapAnywhere : Text.NoWrap
    color: "transparent"
    font.family: target ? target.font.family : ""
    font.pixelSize: target ? target.font.pixelSize : 16
    font.bold: target ? target.font.bold : false
}
