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
    property color paletteText: "#ffffff"
    property color text: imageMode ? surfaceColor("imageText", paletteText) : paletteText
    // 设置页可修改，全局控件会随之更新。
    property color border: "#2f8cff"
    property color paletteMutedText: "#bbbbbb"
    property color banned: imageMode ? surfaceColor("imageMuted", paletteMutedText) : paletteMutedText

    property string gui_theme: "dark"

    readonly property color error: isLight ? (imageMode ? "#4f0b17" : "#961c2e") : "#FF0000"
    readonly property color warning: isLight ? (imageMode ? "#3d2005" : "#6d400c") : "#e0a33b"

    readonly property color transparent: "transparent"
    readonly property color nest_light: "#10ffffff"
    readonly property color mask: "#33000000"

    // 主题配色状态与调色板统一由 Colors 管理。
    property color themeColor: "#2f8cff"
    readonly property var accentChoices: ["#2f8cff", "#8c6bff", "#de638e", "#2faf78", "#df963b"]
    property color backgroundColor: "#1b1d27"
    property string colorScheme: "midnight"

    readonly property var colorSchemes: ThemeCatalog.choices()

    // gui_theme names the icon variant, so "dark" there means dark icons on a
    // light surface. Derive the UI mode from the palette instead.
    readonly property bool isLight: !!ThemeCatalog.lightSurfaces[colorScheme]
    readonly property bool imageMode: isLight && Global.backgroundMode === "image"
    readonly property var lightPalette: ThemeCatalog.lightSurfaces[colorScheme] || ({})
    readonly property color panel: isLight ? changeA(foreground, 0.62) : foreground
    readonly property color card: surfaceColor("card", foreground)
    readonly property color input: surfaceColor("input", background)
    readonly property color popup: surfaceColor("popup", background_n)
    readonly property color control: surfaceColor("control", pressed)
    readonly property color disabledSurface: surfaceColor("control", banned)
    readonly property color outline: surfaceColor("outline", text)
    readonly property color placeholder: surfaceColor(imageMode ? "imagePlaceholder" : "placeholder", banned)
    readonly property color selection: surfaceColor("selection", fired)
    readonly property color selectedRow: surfaceColor("selection", banned)
    readonly property color ambientAccent: surfaceColor("ambient", border)
    readonly property color accentText: {
        if (!isLight) return border
        var backgrounds = [background_n, panel, Qt.color(lightPalette.input || background_n),
                           Qt.color(lightPalette.selection || background_n)]
        if (imageMode) backgrounds.push(Qt.color("#8c8c8c"))
        var ink = ThemeCatalog.readableAccent(border, backgrounds)
        return Qt.rgba(ink.r, ink.g, ink.b, border.a)
    }
    readonly property color accentFill: isLight ? accentText : border
    readonly property color accentContent: contrastingText(accentFill)
    readonly property color selectionContent: isLight
            ? contrastingText(Qt.tint(Qt.tint(background_n, changeA(card, 0.38)), changeA(border, 0.78)))
            : background_n

    function surfaceColor(role, fallback) {
        if (!isLight || !lightPalette[role]) return fallback
        var rgb = Qt.color(lightPalette[role])
        return Qt.rgba(rgb.r, rgb.g, rgb.b, fallback.a)
    }

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

    function isMonochromeUiIcon(source) {
        return /^qrc:\/assets\/gui\/(?:typeBar\/(?:(?:Global|UI|Item|Cost|Display|Extra)_(?:dark|light)|Total|UI|Item|Cost|Display)\.png|element\/File_(?:dark|light)\.png|element\/Bar\/new(?:File|Menu)(?:_(?:dark|light))?\.png|titleBar\/(?:close|maximize|minimize|restore)\.png|controls\/(?:about|settings|new_project|open_project|expand_up|expand_down)\.png)$/.test(String(source))
    }

    function whiteUiIconSource(source) {
        var path = String(source)
        return isMonochromeUiIcon(path) ? path.replace(/_dark\.png$/, "_light.png") : path
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
        paletteText = palette.text
        paletteMutedText = palette.banned
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
