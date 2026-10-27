.pragma library

function style(source, inherited) {
    var base = inherited || {color: "white"}
    var result = {color: source.color || base.color || "white"}
    var keys = ["bold", "italic", "underlined", "strikethrough", "obfuscated"]
    keys.forEach(function(key) { result[key] = !!(source[key] || base[key]) })
    return result
}
function source(text, inherited) {
    var original = String(text || "")
    var base = style({}, inherited)
    function component(value, parent) {
        if (Array.isArray(value)) {
            var last = parent
            var all = []
            value.forEach(function(child) {
                var part = component(child, last)
                all = all.concat(part.segments); last = part.style
            })
            return {segments: all, style: last}
        }
        if (typeof value === "string" || typeof value === "number")
            return {segments: [Object.assign({text: String(value)}, parent)], style: parent}
        if (!value || typeof value !== "object") return {segments: [], style: parent}
        var own = Object.assign({}, parent)
        Object.keys(parent).forEach(function(key) { if (value[key] !== undefined) own[key] = value[key] })
        var segments = value.text === undefined ? [] : [Object.assign({text: String(value.text)}, own)]
        if (value.extra !== undefined) segments = segments.concat(component(value.extra, own).segments)
        return {segments: segments, style: own}
    }
    try { return component(JSON.parse(original.trim()), base).segments }
    catch (error) { return original.length ? [Object.assign({text: original}, base)] : [] }
}

function render(format, operations) {
    var out = []
    function appendPart(part) {
        if (!part.length) return
        if (out.length) out = out.concat(source(format.frame.separator))
        out = out.concat(part)
    }
    var visible = operations.filter(function(op) { return op.showInDisplay })
    visible.forEach(function(op) {
        var rules = format.operation
        var costs = op.cost.filter(function(cost) { return !cost.filter && cost.kind !== "execute_condition" })
        var text = []
        costs.forEach(function(cost, costIndex) {
            var member = source(format.member.head)
            var name = Object.assign({text: cost.display}, style(format.member.cost))
            var amount = Object.assign({text: String(cost.amount)}, style(format.member.value))
            member.push(format.member.order === "cost_then_value" ? name : amount)
            member = member.concat(source(format.member.middle))
            member.push(format.member.order === "cost_then_value" ? amount : name)
            member = member.concat(source(format.member.end))
            if (costIndex) text = text.concat(source(rules.separator))
            text = text.concat(member)
        })
        if (!rules.enabled || !String(op.title).trim().length) { appendPart(text); return }
        var title = [Object.assign({text: op.title}, style(rules.title))]
        var middle = costs.length ? source(rules.middle) : []
        appendPart(source(rules.head).concat(rules.order === "title_then_cost" ? title.concat(middle, text) : text.concat(middle, title), source(rules.end)))
    })
    if (out.length) out = source(format.frame.head).concat(out, source(format.frame.end))
    return {text: "", extra: out}
}
function demo(format, operationCount, costCount) {
    var operations = []
    for (var i = 1; i <= operationCount; ++i) {
        var costs = []
        for (var j = 1; j <= costCount; ++j) costs.push({display: "代价" + j, amount: j})
        operations.push({title: "操作" + i, showInDisplay: true, cost: costs})
    }
    return render(format, operations)
}
function html(component) {
    var colors = {black:"#000000",dark_blue:"#0000aa",dark_green:"#00aa00",dark_aqua:"#00aaaa",
        dark_red:"#aa0000",dark_purple:"#aa00aa",gold:"#ffaa00",gray:"#aaaaaa",dark_gray:"#555555",
        blue:"#5555ff",green:"#55ff55",aqua:"#55ffff",red:"#ff5555",light_purple:"#ff55ff",yellow:"#ffff55",white:"#ffffff"}
    return component.extra.map(function(segment) {
        var text = String(segment.text)
        if (segment.obfuscated) text = text.replace(/[^\s]/g, "▓")
        text = text.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")
            .replace(/"/g,"&quot;").replace(/'/g,"&#39;").replace(/\r\n?|\n/g,"<br>")
            .replace(/ /g,"&nbsp;")
        var color = colors[segment.color] || (/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(segment.color) ? segment.color : "#ffffff")
        var decorations = []
        if (segment.underlined) decorations.push("underline")
        if (segment.strikethrough) decorations.push("line-through")
        return '<span style="color:' + color + ';font-weight:' + (segment.bold ? "bold" : "normal")
            + ';font-style:' + (segment.italic ? "italic" : "normal")
            + ';text-decoration:' + (decorations.join(" ") || "none") + '">' + text + '</span>'
    }).join("")
}
