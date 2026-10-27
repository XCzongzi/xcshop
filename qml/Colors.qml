pragma Singleton
import QtQuick
import "../js/ThemeCatalog.js" as ThemeCatalog

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

    property string gui_theme: "dark"

    readonly property color error: "#FF0000"

    readonly property color transparent: "transparent"
    readonly property color nest_light: "#10ffffff"
    readonly property color mask: "#33000000"

    // 主题配色状态与调色板统一由 Colors 管理。
    property color themeColor: "#2f8cff"
    readonly property var accentChoices: ["#2f8cff", "#8c6bff", "#de638e", "#2faf78", "#df963b"]
    property color backgroundColor: "#1b1d27"
    property string colorScheme: "midnight"

    readonly property var colorSchemes: ThemeCatalog.choices()

    function contrastingText(color) {
        function linear(value) {
            return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        }
        var luminance = 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
        return luminance > 0.179 ? "#000000" : "#ffffff"
    }

    function changeA(color,a){
        return Qt.rgba(color.r,color.g,color.b,a)
    }

    function setThemeColor(color) {
        themeColor = color
        border = color
    }

    function colorFromSettings(value) {
        if (typeof value === "string" && value.length)
            return value
        if (value && value.r !== undefined && value.g !== undefined
                && value.b !== undefined) {
            return Qt.rgba(Number(value.r), Number(value.g), Number(value.b),
                           value.a !== undefined ? Number(value.a) : 1)
        }
        return null
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
        var palettes = ThemeCatalog.palettes
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
        gui_theme = palette.gui_theme

        var accent = accentForColorScheme(colorScheme)
        if (accent.length)
            setThemeColor(accent)
    }

    function loadSettings(settings) {
        if (!settings)
            return
        if (settings.colorScheme)
            applyColorScheme(settings.colorScheme)

        // The accent is independent of the palette. Restore it after applying
        // the palette so applyColorScheme() cannot replace the saved choice.
        var savedThemeColor = colorFromSettings(settings.themeColor)
        if (savedThemeColor !== null)
            setThemeColor(savedThemeColor)

        var savedBackgroundColor = colorFromSettings(settings.backgroundColor)
        if (savedBackgroundColor !== null)
            backgroundColor = savedBackgroundColor
    }

    function settingsData() {
        return {
            themeColor: themeColor.toString(),
            backgroundColor: backgroundColor.toString(),
            colorScheme: colorScheme
        }
    }
      
}
