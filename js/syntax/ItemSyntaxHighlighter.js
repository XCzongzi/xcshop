function escapeHtml(value) {
    return String(value)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/\"/g, "&quot;")
            .replace(/ /g, "&#160;")
            .replace(/\n/g, "<br>")
}

function invalidText(source, palette) {
    return "<font color=\"" + palette.invalid + "\">" + escapeHtml(source) + "</font>"
}

function highlight(source, mode, palette, modeHandlers, parser) {
    if (mode === 0)
        return ""
    var handler = modeHandlers[mode]
    return handler ? handler.highlight(source, palette, parser) : invalidText(source, palette)
}

function ranges(source, mode, palette, modeHandlers, parser) {
    if (mode === 0)
        return []
    var handler = modeHandlers[mode]
    return handler ? handler.highlight(source, palette, parser, true)
                   : [{start: 0, length: source.length, color: palette.invalid}]
}

// Keep validation tied to the highlighter's visible contract: a non-empty
// value is considered erroneous exactly when the selected mode paints the
// entire editor with the invalid color.
function isInvalid(source, mode, palette, modeHandlers, parser) {
    var value = source === undefined || source === null ? "" : String(source)
    if (mode === 0 || !value.length)
        return false
    return highlight(value, mode, palette, modeHandlers, parser)
            === invalidText(value, palette)
}
