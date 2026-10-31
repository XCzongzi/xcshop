var LegacyNbt = 1
var ItemComponents = 2

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

function highlight(source, palette, mode, asRanges) {
    function invalidText() {
        return asRanges ? [{start: 0, length: source.length, color: palette.invalid}]
                        : colorText(source, palette.invalid)
    }

    // Macro values are only known at build time. Use same-length numeric
    // placeholders for parsing (valid in IDs, keys, values and quantities),
    // while rendering the original text. Match MacroHighlighter's macro rules.
    var parseSource = source.replace(/\{\{([^{}\r\n]+)\}\}/g, function (macro, name, offset) {
        if (offset > 0 && source.charAt(offset - 1) === "\\")
            return macro
        return macro.replace(/[^\r\n]/g, "0")
    })
    var state = { source: parseSource, position: 0, output: "", ranges: [], bracketDepth: 0, outputPosition: 0 }

    function append(value, color) {
        if (asRanges)
            state.ranges.push({start: state.outputPosition, length: value.length, color: color})
        else
            state.output += colorText(source.slice(state.outputPosition, state.outputPosition + value.length), color)
        state.outputPosition += value.length
    }

    function skipWhitespace() {
        var start = state.position
        while (state.position < state.source.length && /\s/.test(state.source.charAt(state.position)))
            state.position++
        if (state.position > start)
            append(state.source.slice(start, state.position), palette.plain)
    }

    function appendOpeningBracket() {
        append(state.source.charAt(state.position++), palette.brackets[state.bracketDepth % palette.brackets.length])
        state.bracketDepth++
    }

    function appendClosingBracket() {
        state.bracketDepth--
        append(state.source.charAt(state.position++), palette.brackets[state.bracketDepth % palette.brackets.length])
    }

    function appendPunctuation() {
        append(state.source.charAt(state.position++), palette.punctuation)
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
                append(state.source.slice(start, state.position), palette.string)
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
            append(value, palette.number)
        else if (/^(?:true|false)$/i.test(value))
            append(value, palette.boolean)
        else
            append(value, palette.string)
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
        append(state.source.slice(start, state.position), palette.key)
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
            appendPunctuation()
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
            appendPunctuation()
            skipWhitespace()
        }
        return false
    }

    function parseList() {
        appendOpeningBracket()
        skipWhitespace()
        if (/[BIL]/.test(state.source.charAt(state.position))
                && state.source.charAt(state.position + 1) === ";") {
            append(state.source.charAt(state.position++), palette.key)
            appendPunctuation()
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
            appendPunctuation()
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
                appendPunctuation()

            var start = state.position
            while (state.position < state.source.length
                   && /[A-Za-z0-9_+\-.:\/]/.test(state.source.charAt(state.position)))
                state.position++
            if (start === state.position)
                return false
            append(state.source.slice(start, state.position), palette.key)
            skipWhitespace()

            if (state.source.charAt(state.position) === "=") {
                appendPunctuation()
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
            appendPunctuation()
            skipWhitespace()
        }
        return false
    }

    var itemMatch = state.source.match(/^(?:#)?[a-z0-9_.-]+(?::[a-z0-9_+\-.\/]+)?/)
    if (!itemMatch)
        return invalidText()

    state.position = itemMatch[0].length
    append(itemMatch[0], palette.itemId)

    var next = state.source.charAt(state.position)
    if (mode === LegacyNbt && next === "{") {
        if (!parseCompound())
            return invalidText()
    } else if (mode === ItemComponents && next === "[") {
        if (!parseComponents())
            return invalidText()
    } else if (next === "{" || next === "[") {
        return invalidText()
    }

    var rest = state.source.slice(state.position)
    if (!rest.length)
        return asRanges ? state.ranges : state.output
    if (/^\s+$/.test(rest)) {
        append(rest, palette.plain)
        return asRanges ? state.ranges : state.output
    }

    var countMatch = rest.match(/^(\s+)(\d+)$/)
    if (!countMatch)
        return invalidText()
    append(countMatch[1], palette.plain)
    append(countMatch[2], palette.quantity)
    return asRanges ? state.ranges : state.output
}
