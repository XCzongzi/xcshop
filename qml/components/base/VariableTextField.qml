import QtQuick
import xcshop
import "../../../js/syntax/ItemSyntaxHighlighter.js" as ItemSyntaxHighlighter
import "../../../js/syntax/ItemSyntaxParser.js" as ItemSyntaxParser
import "../../../js/syntax/mode-1.js" as SyntaxMode1
import "../../../js/syntax/mode-2.js" as SyntaxMode2

ResizableEditor {
    id: root
    input: textField

    // 0: 禁用语法高亮, 1: 旧版本, 2: 新版堆叠组件
    property int syntaxHighlightMode: 0
    property var syntaxHighlighters: ({
        1: SyntaxMode1,
        2: SyntaxMode2
    })
    property string placeholderText
    readonly property bool syntaxError: isSyntaxError(textField.text)

    // 浅色主题使用高饱和度配色，让不同语法标记保持鲜明的色相差异。
    readonly property string itemIdColor: syntaxInk("#916000", "#ffe08a")
    readonly property string keyColor: syntaxInk("#005bd6", "#a5e8ff")
    readonly property string stringColor: syntaxInk("#087624", "#b9fbc8")
    readonly property string numberColor: syntaxInk("#b34200", "#ffc58a")
    readonly property string quantityColor: syntaxInk("#8429d6", "#e5c5ff")
    readonly property string punctuationColor: syntaxInk("#394456", "#e2e8f0")
    readonly property string booleanColor: syntaxInk("#006f75", "#99f6e4")
    readonly property string invalidColor: syntaxInk("#cb1644", "#ff8a93")

    function syntaxInk(lightColor, darkColor) {
        if (!Colors.isLight) return darkColor
        return lightColor
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
            "brackets": [keyColor, quantityColor, itemIdColor]
        }
    }

    function createHighlightedText(source) {
        return ItemSyntaxHighlighter.highlight(source, syntaxHighlightMode,
                                                syntaxPalette(), syntaxHighlighters,
                                                ItemSyntaxParser)
    }

    function isSyntaxError(source) {
        return ItemSyntaxHighlighter.isInvalid(source, syntaxHighlightMode,
                                                syntaxPalette(), syntaxHighlighters,
                                                ItemSyntaxParser)
    }

    function createHighlightRanges(source) {
        return ItemSyntaxHighlighter.ranges(source, syntaxHighlightMode,
                                           syntaxPalette(), syntaxHighlighters,
                                           ItemSyntaxParser)
    }

    XCTextField {
        id: textField
        z: 0
        isWrap: true
        width: parent.width
        height: root.inputHeight
        placeholderText: root.placeholderText
        background: InputBackground {
            focused: textField.activeFocus
            idleOpacity: 0.50
            color: Colors.changeA(Colors.isLight && root.syntaxHighlightMode !== 0
                                  ? Qt.tint(Colors.input, "#33ffffff") : Colors.input,
                                  focused ? 0.72 : idleOpacity)
        }
        highlightRanges: root.createHighlightRanges(text)
        highlightMacros: root.highlightMacros
        onEditingFinished: root.commit()
    }
}
