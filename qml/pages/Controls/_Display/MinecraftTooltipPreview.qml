import QtQuick
import xcshop

// Reusable Minecraft-style tooltip for display-element previews.  It owns
// both the frame appearance and the JSON-text rendering so callers only pass
// their display format data and member styles.
Item {
    id: root

    property string frameHead: ""
    property string frameEnd: ""
    property string frameSeparator: ""
    property string memberHead: ""
    property string memberMiddle: ""
    property string memberEnd: ""
    property int memberOrder: 0
    property int demoElementCount: 3

    property string elementColor: "white"
    property bool elementBold: false
    property bool elementItalic: false
    property bool elementUnderlined: false
    property bool elementStrikethrough: false
    property bool elementObfuscated: false
    property string valueColor: "white"
    property bool valueBold: false
    property bool valueItalic: false
    property bool valueUnderlined: false
    property bool valueStrikethrough: false
    property bool valueObfuscated: false

    property int horizontalPadding: 18
    property int verticalPadding: 16
    property real backgroundOpacity: 0.76
    property real headerControlsX: 82
    property real headerControlsY: -67

    readonly property var minecraftColors: ({
        "black": "#000000", "dark_blue": "#0000aa", "dark_green": "#00aa00",
        "dark_aqua": "#00aaaa", "dark_red": "#aa0000", "dark_purple": "#aa00aa",
        "gold": "#ffaa00", "gray": "#aaaaaa", "dark_gray": "#555555",
        "blue": "#5555ff", "green": "#55ff55", "aqua": "#55ffff",
        "red": "#ff5555", "light_purple": "#ff55ff", "yellow": "#ffff55",
        "white": "#ffffff"
    })

    implicitWidth: Math.max(126, tooltipText.implicitWidth + horizontalPadding * 2)
    implicitHeight: Math.max(42, tooltipText.contentHeight + verticalPadding * 2)
    width: implicitWidth
    height: implicitHeight

    Row {
        x: root.headerControlsX - root.x
        y: root.headerControlsY
        spacing: 7

        XCText {
            xcText: "演示的元素数量"
            xcFontSize: 12
            boldFont: false
            onCenter: false
            anchors.verticalCenter: parent.verticalCenter
            textColor: Colors.banned
        }
        TextButton {
            text: "−"
            width: 24
            height: 24
            radius: 5
            textSize: 16
            boldFont: false
            enabled: root.demoElementCount > 1
            buttonColor: Colors.changeA(Colors.background, 0.45)
            onClicked: --root.demoElementCount
        }
        Rectangle {
            width: 30
            height: 24
            radius: 5
            color: Colors.changeA(Colors.background, 0.56)
            border.width: 1
            border.color: Colors.changeA(Colors.text, 0.12)
            XCText {
                xcText: root.demoElementCount
                xcFontSize: 12
            }
        }
        TextButton {
            text: "+"
            width: 24
            height: 24
            radius: 5
            textSize: 16
            boldFont: false
            enabled: root.demoElementCount < 16
            buttonColor: Colors.changeA(Colors.background, 0.45)
            onClicked: ++root.demoElementCount
        }
    }

    function defaultMinecraftStyle() {
        return {
            color: "white", bold: false, italic: false, underlined: false,
            strikethrough: false, obfuscated: false
        }
    }

    function copyMinecraftStyle(style) {
        return {
            color: style.color, bold: style.bold, italic: style.italic,
            underlined: style.underlined, strikethrough: style.strikethrough,
            obfuscated: style.obfuscated
        }
    }

    function minecraftColor(value) {
        var color = value === undefined || value === null ? "white" : String(value)
        if (minecraftColors[color] !== undefined)
            return minecraftColors[color]
        return /^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(color) ? color : "#ffffff"
    }

    function escapePreviewHtml(value) {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                            .replace(/>/g, "&gt;").replace(/\"/g, "&quot;")
                            .replace(/'/g, "&#39;").replace(/\n/g, "<br>")
    }

    function stylePreviewText(value, style) {
        var decorations = []
        if (style.underlined)
            decorations.push("underline")
        if (style.strikethrough)
            decorations.push("line-through")
        var content = String(value)
        if (style.obfuscated)
            content = content.replace(/[^\s]/g, "▓")
        var css = "color:" + minecraftColor(style.color)
                + ";font-weight:" + (style.bold ? "bold" : "normal")
                + ";font-style:" + (style.italic ? "italic" : "normal")
        if (decorations.length)
            css += ";text-decoration:" + decorations.join(" ")
        return "<span style=\"" + css + "\">" + escapePreviewHtml(content) + "</span>"
    }

    function minecraftComponentHtml(component, inheritedStyle) {
        var inherited = inheritedStyle || defaultMinecraftStyle()
        if (Array.isArray(component)) {
            var arrayHtml = ""
            var arrayStyle = copyMinecraftStyle(inherited)
            for (var arrayIndex = 0; arrayIndex < component.length; ++arrayIndex) {
                var arrayResult = minecraftComponentHtml(component[arrayIndex], arrayStyle)
                arrayHtml += arrayResult.html
                arrayStyle = arrayResult.style
            }
            return { html: arrayHtml, style: arrayStyle }
        }
        if (typeof component === "string" || typeof component === "number")
            return { html: stylePreviewText(component, inherited), style: copyMinecraftStyle(inherited) }
        if (!component || typeof component !== "object")
            return { html: "", style: copyMinecraftStyle(inherited) }

        var style = copyMinecraftStyle(inherited)
        var styleKeys = ["color", "bold", "italic", "underlined", "strikethrough", "obfuscated"]
        for (var styleIndex = 0; styleIndex < styleKeys.length; ++styleIndex) {
            var styleKey = styleKeys[styleIndex]
            if (component[styleKey] !== undefined)
                style[styleKey] = component[styleKey]
        }

        var html = component.text === undefined ? "" : stylePreviewText(component.text, style)
        if (component.extra !== undefined) {
            var extraResult = minecraftComponentHtml(component.extra, style)
            html += extraResult.html
        }
        return { html: html, style: style }
    }

    function minecraftJsonHtml(source) {
        var input = source === undefined || source === null ? "" : String(source).trim()
        if (!input.length)
            return ""
        try {
            return minecraftComponentHtml(JSON.parse(input), defaultMinecraftStyle()).html
        } catch (error) {
            return stylePreviewText(input, defaultMinecraftStyle())
        }
    }

    function memberValueHtml(value, color, bold, italic, underlined, strikethrough, obfuscated) {
        return stylePreviewText(value, {
            color: color, bold: bold, italic: italic, underlined: underlined,
            strikethrough: strikethrough, obfuscated: obfuscated
        })
    }

    function displayPreviewHtml() {
        var html = minecraftJsonHtml(frameHead)
        for (var index = 1; index <= demoElementCount; ++index) {
            html += minecraftJsonHtml(memberHead)
            var element = memberValueHtml("元素" + index, elementColor, elementBold,
                                          elementItalic, elementUnderlined,
                                          elementStrikethrough, elementObfuscated)
            var value = memberValueHtml(index, valueColor, valueBold,
                                        valueItalic, valueUnderlined,
                                        valueStrikethrough, valueObfuscated)
            var middle = minecraftJsonHtml(memberMiddle)
            html += memberOrder === 0 ? element + middle + value : value + middle + element
            html += minecraftJsonHtml(memberEnd)
            if (index < demoElementCount)
                html += minecraftJsonHtml(frameSeparator)
        }
        return html + minecraftJsonHtml(frameEnd)
    }

    BorderImage {
        anchors.fill: parent
        source: "qrc:/assets/minecraft/gui/item_lore/background.png"
        opacity: root.backgroundOpacity
        border.left: 10
        border.top: 10
        border.right: 10
        border.bottom: 10
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
    }
    BorderImage {
        anchors.fill: parent
        source: "qrc:/assets/minecraft/gui/item_lore/frame.png"
        border.left: 10
        border.top: 10
        border.right: 10
        border.bottom: 10
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
    }
    BorderImage {
        anchors.fill: parent
        anchors.margins: 1
        source: "qrc:/assets/minecraft/gui/item_lore/frame.png"
        border.left: 10
        border.top: 10
        border.right: 10
        border.bottom: 10
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
    }
    Text {
        id: tooltipText
        x: root.horizontalPadding
        y: root.verticalPadding
        width: implicitWidth
        // The first line represents tooltip content that exists above this
        // previewed display section but is intentionally omitted here.
        text: "...<br>" + root.displayPreviewHtml()
        textFormat: Text.RichText
        wrapMode: Text.NoWrap
        color: "#ffffff"
        font.family: "Microsoft YaHei"
        font.pixelSize: 15
        lineHeight: 1.08
    }
}
