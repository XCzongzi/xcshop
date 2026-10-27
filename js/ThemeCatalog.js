.pragma library

var palettes = {
    "midnight": { background: "#1b1d27", backgroundOverlay: "#aa1b1d27", foreground: "#aa41434f", fired: "#c092949c", pressed: "#d06b6c74", text: "#ffffff", banned: "#bbbbbb", highlight: "#4bffffff", gui_theme: "light" },
    "cloud": { background: "#dce2eb", backgroundOverlay: "#e8dce2eb", foreground: "#e0b9c6d8", fired: "#e8b8c9df", pressed: "#f0adbed6", text: "#1c283b", banned: "#303e52", highlight: "#60ffffff",gui_theme: "dark" },
    "slate": { background: "#202b38", backgroundOverlay: "#aa202b38", foreground: "#aa45586c", fired: "#c07b93aa", pressed: "#d0526b82", text: "#f3f8ff", banned: "#b6c2cf", highlight: "#42ffffff", gui_theme: "light" },
    "glacier": { background: "#d0e3ed", backgroundOverlay: "#e8d0e3ed", foreground: "#e0a1c4d7", fired: "#e8a7c9df", pressed: "#f09abed6", text: "#193344", banned: "#29414e", highlight: "#60ffffff", gui_theme: "dark" },
    "violet": { background: "#2b2238", backgroundOverlay: "#aa2b2238", foreground: "#aa5b476d", fired: "#c09b7cb2", pressed: "#d072588a", text: "#fff8ff", banned: "#cbbfd2", highlight: "#45ffffff", gui_theme: "light" },
    "lavender": { background: "#e1d6eb", backgroundOverlay: "#e8e1d6eb", foreground: "#e0bca4d0", fired: "#e8c6aedc", pressed: "#f0bda4d5", text: "#30263f", banned: "#42364f", highlight: "#60ffffff", gui_theme: "dark" },
    "forest": { background: "#162d2d", backgroundOverlay: "#aa162d2d", foreground: "#aa345b58", fired: "#c06f9b91", pressed: "#d046756f", text: "#f3fffb", banned: "#b8cac4", highlight: "#42ffffff", gui_theme: "light" },
    "mint": { background: "#d5e6dc", backgroundOverlay: "#e8d5e6dc", foreground: "#e0a4c8b3", fired: "#e8afd0bb", pressed: "#f0a2c7b1", text: "#20392f", banned: "#2c4539", highlight: "#60ffffff", gui_theme: "dark" },
    "amber": { background: "#33251d", backgroundOverlay: "#aa33251d", foreground: "#aa654c3c", fired: "#c0a88769", pressed: "#d0815b43", text: "#fff9f3", banned: "#d3c2b4", highlight: "#45ffffff", gui_theme: "light" },
    "parchment": { background: "#eadbc1", backgroundOverlay: "#e8eadbc1", foreground: "#e0cdb38b", fired: "#e8d9bd90", pressed: "#f0d1b17f", text: "#3c3023", banned: "#493d2d", highlight: "#60ffffff", gui_theme: "dark" },
    "rose": { background: "#38232e", backgroundOverlay: "#aa38232e", foreground: "#aa704658", fired: "#c0a57b8b", pressed: "#d089596e", text: "#fff7f9", banned: "#d5bec6", highlight: "#45ffffff", gui_theme: "light" },
    "blush": { background: "#ebd6df", backgroundOverlay: "#e8ebd6df", foreground: "#e0ce9fb3", fired: "#e8d8aec1", pressed: "#f0cfa0b7", text: "#3e2933", banned: "#4d3340", highlight: "#60ffffff", gui_theme: "dark" }
}

var names = {"midnight":"深夜","cloud":"云白","slate":"石板","glacier":"冰川","violet":"紫雾","lavender":"薰衣草","forest":"森林","mint":"薄荷","amber":"琥珀","parchment":"羊皮纸","rose":"玫瑰","blush":"樱粉"}

// RGB roles are independent of material opacity. Controls retain their existing
// alpha/blur and choose a role according to the surface they actually draw.
var lightSurfaces = {
    cloud: {
        card: "#c1cdde", input: "#c0ccdd", popup: "#e7edf5", control: "#c4cfdf",
        outline: "#23364e", placeholder: "#213249", selection: "#a5b9d4", ambient: "#7186a3",
        imageText: "#0c1625", imageMuted: "#000000", imagePlaceholder: "#000000"
    },
    glacier: {
        card: "#aacbdd", input: "#aecddd", popup: "#daebf4", control: "#bad6e5",
        outline: "#173d54", placeholder: "#173344", selection: "#96bbd2", ambient: "#528ca9",
        imageText: "#091a25", imageMuted: "#000000", imagePlaceholder: "#000000"
    },
    lavender: {
        card: "#c4add7", input: "#cab3dd", popup: "#eadef2", control: "#d6c3e5",
        outline: "#3e2756", placeholder: "#322440", selection: "#bca2d2", ambient: "#9473b0",
        imageText: "#190f25", imageMuted: "#000000", imagePlaceholder: "#000000"
    },
    mint: {
        card: "#aed0bd", input: "#b5d2c0", popup: "#dfede4", control: "#c3dccd",
        outline: "#214534", placeholder: "#1f382a", selection: "#9fc3ad", ambient: "#60957a",
        imageText: "#0c1d14", imageMuted: "#000000", imagePlaceholder: "#000000"
    },
    parchment: {
        card: "#d6bd98", input: "#d5bf9a", popup: "#f0e2c9", control: "#e1ccaa",
        outline: "#513b20", placeholder: "#392b19", selection: "#cdb082", ambient: "#b38b54",
        imageText: "#201407", imageMuted: "#000000", imagePlaceholder: "#000000"
    },
    blush: {
        card: "#d5a9bc", input: "#dcb5c6", popup: "#f1dfe7", control: "#e5c5d3",
        outline: "#542d40", placeholder: "#3e2431", selection: "#cda1b5", ambient: "#b77994",
        imageText: "#211019", imageMuted: "#000000", imagePlaceholder: "#000000"
    }
}

function luminance(color) {
    function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
}

function contrast(a, b) {
    var first = luminance(a), second = luminance(b)
    return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05)
}

// Accent choices stay user-owned. Derive ink for small links and filled actions
// without changing the stored accent or its use in decorative highlights.
function readableAccent(accent, backgrounds) {
    var ink = { r: accent.r, g: accent.g, b: accent.b }
    for (var step = 0; step < 64; ++step) {
        if (backgrounds.every(function(background) { return contrast(ink, background) >= 6 }))
            break
        ink = { r: ink.r * 0.95, g: ink.g * 0.95, b: ink.b * 0.95 }
    }
    return ink
}

function opaque(value) { return value.length === 9 ? "#" + value.substring(3) : value }
function choices() {
    return Object.keys(palettes).map(function(id) {
        var palette = palettes[id]
        return { id: id, name: names[id], mode: palette.gui_theme === "light" ? "深色" : "浅色",
                 background: palette.background, foreground: opaque(palette.foreground),
                 surface: opaque(palette.pressed), text: palette.text }
    })
}
