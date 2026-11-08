.pragma library
function textStyle() {
    return {color: "", bold: false, underlined: false, italic: false,
        strikethrough: false, obfuscated: false}
}
function item() {
    return {item: "", itemSyntaxError: false,
        display: {mode: "original", element: ""}, operationsFrom: "", operations: []}
}
function operation(title) {
    return {title: title === undefined ? "" : String(title), showInDisplay: true,
        successHint: true, failHint: true, returnOnSuccess: false, uniqueTrigger: false,
        priority: false, cost: [],
        trigger: {mode: {kind: "take_item", filter: {kind: "none"}},
            execute: {kind: "grant_item"}}}
}
function display() {
    return {frame: {head: "", end: "", separator: ""},
        member: {order: "cost_then_value", head: "", middle: "", end: "",
            cost: textStyle(), value: textStyle()},
        operation: {enabled: false, order: "title_then_cost", head: "", middle: "", end: "",
            separator: "", title: textStyle()},
        hint: {success: {text: "", sound: ""}, fail: {text: "", sound: ""}}}
}
