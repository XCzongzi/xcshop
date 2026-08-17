pragma Singleton
import QtQuick


QtObject {

    property color background_n: "#1b1d27"
    property color background: "#aa1b1d27"
    property color foreground: "#aa41434f"
    readonly property color shadow: '#aa050505'
    property color glass_highlight: '#4bffffff'
    property color fired: "#aa92949c"
    property color pressed: "#aa6b6c74"
    property color text: "#ffffff"
    // 设置页可修改，全局控件会随之更新。
    property color border: "#2f8cff"
    property color banned: "#bbbbbb"
    readonly property color error: "#FF0000"

    readonly property color transparent: "transparent"
    readonly property color nest_light: "#10ffffff"
    readonly property color mask: "#33000000"

    // 主题配色状态与调色板统一由 Colors 管理。
    property color themeColor: "#2f8cff"
    readonly property var accentChoices: ["#2f8cff", "#8c6bff", "#de638e", "#2faf78", "#df963b"]
    property color backgroundColor: "#1b1d27"
    property string colorScheme: "midnight"

    function changeA(color,a){
        return Qt.rgba(color.r,color.g,color.b,a)
    }

    function setThemeColor(color) {
        themeColor = color
        border = color
    }

    function accentForColorScheme(scheme) {
        var accentByScheme = {
            slate: accentChoices[0], glacier: accentChoices[0],
            violet: accentChoices[1], lavender: accentChoices[1],
            forest: accentChoices[3], mint: accentChoices[3],
            amber: accentChoices[4], parchment: accentChoices[4],
            rose: accentChoices[2], blush: accentChoices[2]
        }
        return accentByScheme[scheme] || ""
    }

    function applyColorScheme(scheme) {
        var palettes = {
            "midnight": { background: "#1b1d27", backgroundOverlay: "#aa1b1d27", foreground: "#aa41434f", fired: "#c092949c", pressed: "#d06b6c74", text: "#ffffff", banned: "#bbbbbb", highlight: "#4bffffff" },
            "cloud": { background: "#edf2f7", backgroundOverlay: "#e8edf2f7", foreground: "#e0dce5ee", fired: "#e8b6c3d1", pressed: "#f0aebaca", text: "#172033", banned: "#637087", highlight: "#60ffffff" },
            "slate": { background: "#202b38", backgroundOverlay: "#aa202b38", foreground: "#aa45586c", fired: "#c07b93aa", pressed: "#d0526b82", text: "#f3f8ff", banned: "#b6c2cf", highlight: "#42ffffff" },
            "glacier": { background: "#eaf5fa", backgroundOverlay: "#e8eaf5fa", foreground: "#e0d5e8f0", fired: "#e8a6c6d5", pressed: "#f087adbf", text: "#123047", banned: "#5d7585", highlight: "#60ffffff" },
            "violet": { background: "#2b2238", backgroundOverlay: "#aa2b2238", foreground: "#aa5b476d", fired: "#c09b7cb2", pressed: "#d072588a", text: "#fff8ff", banned: "#cbbfd2", highlight: "#45ffffff" },
            "lavender": { background: "#f4eff9", backgroundOverlay: "#e8f4eff9", foreground: "#e0e6dcef", fired: "#e8c5afd5", pressed: "#f0b9a2c9", text: "#2c2039", banned: "#75667e", highlight: "#60ffffff" },
            "forest": { background: "#162d2d", backgroundOverlay: "#aa162d2d", foreground: "#aa345b58", fired: "#c06f9b91", pressed: "#d046756f", text: "#f3fffb", banned: "#b8cac4", highlight: "#42ffffff" },
            "mint": { background: "#e9f5ef", backgroundOverlay: "#e8e9f5ef", foreground: "#e0d4e9de", fired: "#e8a8cdb9", pressed: "#f088b59c", text: "#17352d", banned: "#5e7a6e", highlight: "#60ffffff" },
            "amber": { background: "#33251d", backgroundOverlay: "#aa33251d", foreground: "#aa654c3c", fired: "#c0a88769", pressed: "#d0815b43", text: "#fff9f3", banned: "#d3c2b4", highlight: "#45ffffff" },
            "parchment": { background: "#fbf3e5", backgroundOverlay: "#e8fbf3e5", foreground: "#e0ead8bd", fired: "#e8d5b888", pressed: "#f0c7a66f", text: "#3d2d1f", banned: "#81705c", highlight: "#60ffffff" },
            "rose": { background: "#38232e", backgroundOverlay: "#aa38232e", foreground: "#aa704658", fired: "#c0a57b8b", pressed: "#d089596e", text: "#fff7f9", banned: "#d5bec6", highlight: "#45ffffff" },
            "blush": { background: "#f9edf1", backgroundOverlay: "#e8f9edf1", foreground: "#e0eed8e1", fired: "#e8d3a8b9", pressed: "#f0c5899f", text: "#3b2430", banned: "#816371", highlight: "#60ffffff" }
        }
        var palette = palettes[scheme] || palettes.midnight
        colorScheme = palettes[scheme] ? scheme : "midnight"
        backgroundColor = palette.background
        background_n = palette.background
        background = palette.backgroundOverlay
        foreground = palette.foreground
        fired = palette.fired
        pressed = palette.pressed
        text = palette.text
        banned = palette.banned
        glass_highlight = palette.highlight

        var accent = accentForColorScheme(colorScheme)
        if (accent.length)
            setThemeColor(accent)
    }

    function loadSettings(settings) {
        if (!settings)
            return
        if (settings.themeColor)
            themeColor = settings.themeColor
        if (settings.colorScheme)
            applyColorScheme(settings.colorScheme)
        if (settings.backgroundColor)
            backgroundColor = settings.backgroundColor
        border = themeColor
    }

    function settingsData() {
        return {
            themeColor: themeColor,
            backgroundColor: backgroundColor,
            colorScheme: colorScheme
        }
    }
      
}
