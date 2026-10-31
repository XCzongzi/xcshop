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

    // 浅色背景使用更深的墨色，深色背景使用粉彩。
    readonly property bool lightSyntaxTheme: (Colors.background_n.r * 0.2126
                                               + Colors.background_n.g * 0.7152
                                               + Colors.background_n.b * 0.0722) > 0.58
    readonly property int syntaxPaletteRevision: lightSyntaxTheme ? 1 : 0
    readonly property string itemIdColor: syntaxInk("#704600", "#ffe08a")
    readonly property string keyColor: syntaxInk("#004c88", "#a5e8ff")
    readonly property string stringColor: syntaxInk("#13552d", "#b9fbc8")
    readonly property string numberColor: syntaxInk("#853000", "#ffc58a")
    readonly property string quantityColor: syntaxInk("#56308b", "#e5c5ff")
    readonly property string punctuationColor: syntaxInk("#344350", "#e2e8f0")
    readonly property string booleanColor: syntaxInk("#005a49", "#99f6e4")
    readonly property string invalidColor: syntaxInk("#9e1e2b", "#ff8a93")

    function syntaxInk(lightColor, darkColor) {
        if (!lightSyntaxTheme) return darkColor
        return Qt.darker(lightColor, Colors.imageMode ? 1.4 : 1.15).toString()
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
            "brackets": lightSyntaxTheme ? [keyColor, quantityColor, itemIdColor]
                                         : ["#a5e8ff", "#e5c5ff", "#ffe08a"]
        }
    }

    function createHighlightedText(source) {
        syntaxPaletteRevision
        return ItemSyntaxHighlighter.highlight(source, syntaxHighlightMode,
                                                syntaxPalette(), syntaxHighlighters,
                                                ItemSyntaxParser)
    }

    function isSyntaxError(source) {
        syntaxPaletteRevision
        return ItemSyntaxHighlighter.isInvalid(source, syntaxHighlightMode,
                                                syntaxPalette(), syntaxHighlighters,
                                                ItemSyntaxParser)
    }

    function createHighlightRanges(source) {
        syntaxPaletteRevision
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
        highlightRanges: root.createHighlightRanges(text)
        highlightMacros: root.highlightMacros
        onEditingFinished: root.commit()
    }
}
