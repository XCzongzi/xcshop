import QtQuick
import xcshop
import "../../../js/syntax/ItemSyntaxHighlighter.js" as ItemSyntaxHighlighter
import "../../../js/syntax/ItemSyntaxParser.js" as ItemSyntaxParser
import "../../../js/syntax/mode-1.js" as SyntaxMode1
import "../../../js/syntax/mode-2.js" as SyntaxMode2

Item {
    id: root

    // 0: disabled, 1: legacy item NBT, 2: item stack components
    property int syntaxHighlightMode: 0
    property var syntaxHighlighters: ({
        1: SyntaxMode1,
        2: SyntaxMode2
    })
    property int syntaxHighlighterRevision: 0
    property string placeholderText
    property string content

    readonly property string itemIdColor: "#ffd54f"
    readonly property string keyColor: "#79c0ff"
    readonly property string stringColor: "#a5d6a7"
    readonly property string numberColor: "#ffb86c"
    readonly property string quantityColor: "#c792ea"
    readonly property string punctuationColor: "#b0bec5"
    readonly property string booleanColor: "#82e0aa"
    readonly property string invalidColor: "#ff5555"

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
            "brackets": ["#79c0ff", "#c792ea", "#ffd54f"]
        }
    }

    function createHighlightedText(source) {
        syntaxHighlighterRevision
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
