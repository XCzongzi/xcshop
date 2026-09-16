function escapeHtml(value) {
    return String(value)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/\"/g, "&quot;")
            .replace(/ /g, "&#160;")
            .replace(/\n/g, "<br>")
}

function escapedByBackslash(source, position) {
    return position > 0 && source.charAt(position - 1) === "\\"
}

function highlight(source, macroColor) {
    var text = source === undefined || source === null ? "" : String(source)
    var output = ""
    var outputPosition = 0
    var searchPosition = 0

    while (searchPosition < text.length) {
        var start = text.indexOf("{{", searchPosition)
        if (start < 0)
            break

        var end = text.indexOf("}}", start + 2)
        var name = end < 0 ? "" : text.slice(start + 2, end)
        if (end < 0 || !name.length || /[{}\r\n]/.test(name)
                || escapedByBackslash(text, start)) {
            searchPosition = start + 2
            continue
        }

        output += "<font color=\"#00000000\">"
                + escapeHtml(text.slice(outputPosition, start)) + "</font>"
        output += "<font color=\"" + macroColor + "\">"
                + escapeHtml(text.slice(start, end + 2)) + "</font>"
        outputPosition = end + 2
        searchPosition = outputPosition
    }

    output += "<font color=\"#00000000\">"
            + escapeHtml(text.slice(outputPosition)) + "</font>"
    return output
}
