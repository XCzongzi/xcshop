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
