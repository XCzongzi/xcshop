import QtQuick
import xcshop
import "../../../js/syntax/ItemSyntaxHighlighter.js" as ItemSyntaxHighlighter
import "../../../js/syntax/ItemSyntaxParser.js" as ItemSyntaxParser
import "../../../js/syntax/mode-1.js" as SyntaxMode1
import "../../../js/syntax/mode-2.js" as SyntaxMode2

Item {
    id: root

    // 0: 禁用语法高亮, 1: 旧版本, 2: 新版堆叠组件
    property int syntaxHighlightMode: 0
    property var syntaxHighlighters: ({
        1: SyntaxMode1,
        2: SyntaxMode2
    })
    property int syntaxHighlighterRevision: 0
    property string placeholderText
    property string content
    readonly property string inputContent: textField.text

    // 语法覆盖层独立适配浅/深背景：浅色使用更深的墨色，深色使用高亮但不过曝的粉彩。
    readonly property bool lightSyntaxTheme: (Colors.background_n.r * 0.2126
                                               + Colors.background_n.g * 0.7152
                                               + Colors.background_n.b * 0.0722) > 0.58
    readonly property int syntaxPaletteRevision: lightSyntaxTheme ? 1 : 0
    readonly property string itemIdColor: lightSyntaxTheme ? "#8a5800" : "#ffe08a"
    readonly property string keyColor: lightSyntaxTheme ? "#005fae" : "#a5e8ff"
    readonly property string stringColor: lightSyntaxTheme ? "#176b38" : "#b9fbc8"
    readonly property string numberColor: lightSyntaxTheme ? "#a43b00" : "#ffc58a"
    readonly property string quantityColor: lightSyntaxTheme ? "#6940a5" : "#e5c5ff"
    readonly property string punctuationColor: lightSyntaxTheme ? "#4b5b6a" : "#e2e8f0"
    readonly property string booleanColor: lightSyntaxTheme ? "#08745f" : "#99f6e4"
    readonly property string invalidColor: lightSyntaxTheme ? "#bd1f2d" : "#ff8a93"

    signal accepted()

    Behavior on height {
        NumberAnimation {
            duration: 120
            easing.type: Easing.InOutQuad
        }
    }

    function getContent() {
        return textField.text
    }

    // Lets popup editors update both the public value and the actual input
    // immediately, including when the field has not lost focus yet.
    function setContent(value) {
        content = value === undefined || value === null ? "" : String(value)
        textField.text = content
    }

    function syntaxPalette() {
        return {
            "plain": Colors.text,
            "itemId": itemIdColor,
            "key": keyColor,
            "string": stringColor,
            "number": numberColor,
            "quantity": quantityColor,
            "punctuation": punctuationColor,
            "boolean": booleanColor,
            "invalid": invalidColor,
            "brackets": lightSyntaxTheme ? ["#005fae", "#6940a5", "#8a5800"]
                                         : ["#a5e8ff", "#e5c5ff", "#ffe08a"]
        }
    }

    function createHighlightedText(source) {
        syntaxHighlighterRevision
        syntaxPaletteRevision
        return ItemSyntaxHighlighter.highlight(source, syntaxHighlightMode,
                                                syntaxPalette(), syntaxHighlighters,
                                                ItemSyntaxParser)
    }

    function registerSyntaxHighlighter(mode, highlighter) {
        if (mode > 0 && highlighter && typeof highlighter.highlight === "function") {
            syntaxHighlighters[mode] = highlighter
            syntaxHighlighterRevision++
        }
    }

    function unregisterSyntaxHighlighter(mode) {
        if (mode > 2 && syntaxHighlighters[mode]) {
            delete syntaxHighlighters[mode]
            syntaxHighlighterRevision++
        }
    }

    onContentChanged: textField.text = content

    Text {
        id: syntaxOverlay
        visible: root.syntaxHighlightMode !== 0 && textField.text.length > 0
        z: 1
        x: textField.leftPadding
        y: textField.topPadding
        width: textField.width - textField.leftPadding - textField.rightPadding
        height: textField.height - textField.topPadding - textField.bottomPadding
        clip: true
        text: root.createHighlightedText(textField.text)
        textFormat: Text.RichText
        wrapMode: Text.WrapAnywhere
        color: Colors.text
        font.family: textField.font.family
        font.pixelSize: textField.font.pixelSize
        font.bold: textField.font.bold
    }

    Rectangle {
        visible: root.syntaxHighlightMode !== 0 && textField.activeFocus
        z: 2
        x: textField.x + textField.leftPadding + textField.positionToRectangle(textField.cursorPosition).x
        y: textField.y + textField.topPadding + textField.positionToRectangle(textField.cursorPosition).y
        width: 1
        height: textField.font.pixelSize + 2
        color: Colors.text
    }

    XCTextField {
        id: textField
        z: 0
        isWrap: true
        width: parent.width
        height: parent.height - 35
        placeholderText: root.placeholderText
        color: root.syntaxHighlightMode === 0 ? Colors.text : Colors.transparent
        onEditingFinished: {
            root.content = text
            root.accepted()
        }
    }

    Row {
        y: textField.height + 3
        x: parent.width - width
        ImageButton {
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_up.png"
            onClicked: root.height = Math.max(root.height - 128, 128)
        }
        ImageButton {
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_down.png"
            onClicked: root.height = root.height + 128
        }
    }
}
