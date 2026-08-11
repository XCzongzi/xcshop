import QtQuick
import xcshop

Item {
    id: root

    //AI生成的语法高亮功能，0为关闭，1为旧版nbt，2为新版物品堆叠组件
    property int syntaxHighlightMode: 0


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

    function escapeHtml(value) {
        return String(value)
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/\"/g, "&quot;")
                .replace(/ /g, "&#160;")
                .replace(/\n/g, "<br>")
    }

    function colorText(value, color) {
        return "<font color=\"" + color + "\">" + escapeHtml(value) + "</font>"
    }

    function invalidText(value) {
        return colorText(value, invalidColor)
    }

    function createHighlightedText(source) {
        if (syntaxHighlightMode === 0)
            return ""
        if (syntaxHighlightMode !== 1 && syntaxHighlightMode !== 2)
            return invalidText(source)

        var state = { source: source, position: 0, output: "", bracketDepth: 0 }

        function append(value, color) {
            state.output += colorText(value, color)
        }

        function appendPlain(value) {
            append(value, Colors.text)
        }

        function bracketColor(depth) {
            var colors = ["#79c0ff", "#c792ea", "#ffd54f"]
            return colors[depth % colors.length]
        }

        function appendOpeningBracket() {
            append(state.source.charAt(state.position++), bracketColor(state.bracketDepth))
            state.bracketDepth++
        }

        function appendClosingBracket() {
            state.bracketDepth--
            append(state.source.charAt(state.position++), bracketColor(state.bracketDepth))
        }

        function skipWhitespace() {
            var start = state.position
            while (state.position < state.source.length && /\s/.test(state.source.charAt(state.position)))
                state.position++
            if (state.position > start)
                appendPlain(state.source.slice(start, state.position))
        }

        function parseQuoted() {
            var quote = state.source.charAt(state.position)
            var start = state.position++
            while (state.position < state.source.length) {
                var character = state.source.charAt(state.position++)
                if (character === "\\") {
                    if (state.position >= state.source.length)
                        return false
                    state.position++
                } else if (character === quote) {
                    append(state.source.slice(start, state.position), stringColor)
                    return true
                }
            }
            return false
        }

        function parseBareValue() {
            var start = state.position
            while (state.position < state.source.length
                   && !/[\s,\[\]\{}=]/.test(state.source.charAt(state.position)))
                state.position++
            if (start === state.position)
                return false

            var value = state.source.slice(start, state.position)
            if (!/^[A-Za-z0-9_+\-.\/]+(?::[A-Za-z0-9_+\-.\/]+)?$/.test(value))
                return false
            if (/^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?[bBsSlLfFdD]?$/.test(value))
                append(value, numberColor)
            else if (/^(?:true|false)$/i.test(value))
                append(value, booleanColor)
            else
                append(value, stringColor)
            return true
        }

        function parseKey() {
            if (state.source.charAt(state.position) === "\"" || state.source.charAt(state.position) === "'")
                return parseQuoted()

            var start = state.position
            while (state.position < state.source.length
                   && /[A-Za-z0-9_+\-.]/.test(state.source.charAt(state.position)))
                state.position++
            if (start === state.position)
                return false
            append(state.source.slice(start, state.position), keyColor)
            return true
        }

        function parseCompound() {
            appendOpeningBracket()
            skipWhitespace()
            if (state.source.charAt(state.position) === "}") {
                appendClosingBracket()
                return true
            }

            while (state.position < state.source.length) {
                if (!parseKey())
                    return false
                skipWhitespace()
                if (state.source.charAt(state.position) !== ":")
                    return false
                append(state.source.charAt(state.position++), punctuationColor)
                skipWhitespace()
                if (!parseValue())
                    return false
                skipWhitespace()
                if (state.source.charAt(state.position) === "}") {
                    appendClosingBracket()
                    return true
                }
                if (state.source.charAt(state.position) !== ",")
                    return false
                append(state.source.charAt(state.position++), punctuationColor)
                skipWhitespace()
            }
            return false
        }

        function parseList() {
            appendOpeningBracket()
            skipWhitespace()

            if (/[BIL]/.test(state.source.charAt(state.position))
                    && state.source.charAt(state.position + 1) === ";") {
                append(state.source.charAt(state.position++), keyColor)
                append(state.source.charAt(state.position++), punctuationColor)
                skipWhitespace()
            }

            if (state.source.charAt(state.position) === "]") {
                appendClosingBracket()
                return true
            }

            while (state.position < state.source.length) {
                if (!parseValue())
                    return false
                skipWhitespace()
                if (state.source.charAt(state.position) === "]") {
                    appendClosingBracket()
                    return true
                }
                if (state.source.charAt(state.position) !== ",")
                    return false
                append(state.source.charAt(state.position++), punctuationColor)
                skipWhitespace()
            }
            return false
        }

        function parseValue() {
            var character = state.source.charAt(state.position)
            if (character === "{")
                return parseCompound()
            if (character === "[")
                return parseList()
            if (character === "\"" || character === "'")
                return parseQuoted()
            return parseBareValue()
        }

        function parseComponents() {
            appendOpeningBracket()
            skipWhitespace()
            if (state.source.charAt(state.position) === "]") {
                appendClosingBracket()
                return true
            }

            while (state.position < state.source.length) {
                if (state.source.charAt(state.position) === "!")
                    append(state.source.charAt(state.position++), punctuationColor)

                var start = state.position
                while (state.position < state.source.length
                       && /[A-Za-z0-9_+\-.:\/]/.test(state.source.charAt(state.position)))
                    state.position++
                if (start === state.position)
                    return false
                append(state.source.slice(start, state.position), keyColor)
                skipWhitespace()

                if (state.source.charAt(state.position) === "=") {
                    append(state.source.charAt(state.position++), punctuationColor)
                    skipWhitespace()
                    if (!parseValue())
                        return false
                    skipWhitespace()
                }

                if (state.source.charAt(state.position) === "]") {
                    appendClosingBracket()
                    return true
                }
                if (state.source.charAt(state.position) !== ",")
                    return false
                append(state.source.charAt(state.position++), punctuationColor)
                skipWhitespace()
            }
            return false
        }

        var itemMatch = source.match(/^(?:#)?[a-z0-9_.-]+(?::[a-z0-9_+\-.\/]+)?/)
        if (!itemMatch)
            return invalidText(source)

        state.position = itemMatch[0].length
        append(itemMatch[0], itemIdColor)

        var next = state.source.charAt(state.position)
        if (syntaxHighlightMode === 1 && next === "{") {
            if (!parseCompound())
                return invalidText(source)
        } else if (syntaxHighlightMode === 2 && next === "[") {
            if (!parseComponents())
                return invalidText(source)
        } else if (next === "{" || next === "[") {
            return invalidText(source)
        }

        var rest = state.source.slice(state.position)
        if (!rest.length)
            return state.output
        if (/^\s+$/.test(rest)) {
            appendPlain(rest)
            return state.output
        }

        var countMatch = rest.match(/^(\s+)(\d+)$/)
        if (!countMatch)
            return invalidText(source)
        appendPlain(countMatch[1])
        append(countMatch[2], quantityColor)
        return state.output
    }

    onContentChanged: {
        textField.text = content
    }

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
            id: expand_up
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_up.png"
            onClicked: root.height = Math.max(root.height - 128, 128)
        }
        ImageButton {
            id: expand_down
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_down.png"
            onClicked: root.height = root.height + 128
        }
    }
}
