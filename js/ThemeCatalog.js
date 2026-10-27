.pragma library

var palettes = {
    "midnight": { background: "#1b1d27", backgroundOverlay: "#aa1b1d27", foreground: "#aa41434f", fired: "#c092949c", pressed: "#d06b6c74", text: "#ffffff", banned: "#bbbbbb", highlight: "#4bffffff", gui_theme: "light" },
    "cloud": { background: "#edf2f7", backgroundOverlay: "#e8edf2f7", foreground: "#e0dce5ee", fired: "#e8b6c3d1", pressed: "#f0aebaca", text: "#172033", banned: "#637087", highlight: "#60ffffff",gui_theme: "dark" },
    "slate": { background: "#202b38", backgroundOverlay: "#aa202b38", foreground: "#aa45586c", fired: "#c07b93aa", pressed: "#d0526b82", text: "#f3f8ff", banned: "#b6c2cf", highlight: "#42ffffff", gui_theme: "light" },
    "glacier": { background: "#eaf5fa", backgroundOverlay: "#e8eaf5fa", foreground: "#e0d5e8f0", fired: "#e8a6c6d5", pressed: "#f087adbf", text: "#123047", banned: "#5d7585", highlight: "#60ffffff", gui_theme: "dark" },
    "violet": { background: "#2b2238", backgroundOverlay: "#aa2b2238", foreground: "#aa5b476d", fired: "#c09b7cb2", pressed: "#d072588a", text: "#fff8ff", banned: "#cbbfd2", highlight: "#45ffffff", gui_theme: "light" },
    "lavender": { background: "#f4eff9", backgroundOverlay: "#e8f4eff9", foreground: "#e0e6dcef", fired: "#e8c5afd5", pressed: "#f0b9a2c9", text: "#2c2039", banned: "#75667e", highlight: "#60ffffff", gui_theme: "dark" },
    "forest": { background: "#162d2d", backgroundOverlay: "#aa162d2d", foreground: "#aa345b58", fired: "#c06f9b91", pressed: "#d046756f", text: "#f3fffb", banned: "#b8cac4", highlight: "#42ffffff", gui_theme: "light" },
    "mint": { background: "#e9f5ef", backgroundOverlay: "#e8e9f5ef", foreground: "#e0d4e9de", fired: "#e8a8cdb9", pressed: "#f088b59c", text: "#17352d", banned: "#5e7a6e", highlight: "#60ffffff", gui_theme: "dark" },
    "amber": { background: "#33251d", backgroundOverlay: "#aa33251d", foreground: "#aa654c3c", fired: "#c0a88769", pressed: "#d0815b43", text: "#fff9f3", banned: "#d3c2b4", highlight: "#45ffffff", gui_theme: "light" },
    "parchment": { background: "#fbf3e5", backgroundOverlay: "#e8fbf3e5", foreground: "#e0ead8bd", fired: "#e8d5b888", pressed: "#f0c7a66f", text: "#3d2d1f", banned: "#81705c", highlight: "#60ffffff", gui_theme: "dark" },
    "rose": { background: "#38232e", backgroundOverlay: "#aa38232e", foreground: "#aa704658", fired: "#c0a57b8b", pressed: "#d089596e", text: "#fff7f9", banned: "#d5bec6", highlight: "#45ffffff", gui_theme: "light" },
    "blush": { background: "#f9edf1", backgroundOverlay: "#e8f9edf1", foreground: "#e0eed8e1", fired: "#e8d3a8b9", pressed: "#f0c5899f", text: "#3b2430", banned: "#816371", highlight: "#60ffffff", gui_theme: "dark" }
}

var names = {"midnight":"深夜","cloud":"云白","slate":"石板","glacier":"冰川","violet":"紫雾","lavender":"薰衣草","forest":"森林","mint":"薄荷","amber":"琥珀","parchment":"羊皮纸","rose":"玫瑰","blush":"樱粉"}

function opaque(value) { return value.length === 9 ? "#" + value.substring(3) : value }
function choices() {
    return Object.keys(palettes).map(function(id) {
        var palette = palettes[id]
        return { id: id, name: names[id], mode: palette.gui_theme === "light" ? "深色" : "浅色",
                 background: palette.background, foreground: opaque(palette.foreground),
                 surface: opaque(palette.pressed), text: palette.text }
    })
}
