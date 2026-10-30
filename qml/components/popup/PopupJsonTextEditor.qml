pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop
import "../../../js/MinecraftTextColors.js" as MinecraftTextColors

// Visual editor for Minecraft JSON text components. It intentionally exports
// ordinary { text, color, ... , extra } components so the result can be used
// directly in tellraw/title style fields.
PopupFrame {
    id: root

    title: "编辑 JSON 文本"
    property string jsonText: ""
    property string parseError: ""
    readonly property var colorOptions: MinecraftTextColors.colors

    ListModel { id: segmentModel }

    dialogWidth: 1040
    dialogHeight: 720

    function defaultSegment(text) {
        return {
            "text": text === undefined ? "文字" : String(text),
            "color": "white",
            "bold": false,
            "italic": false,
            "underlined": false,
            "strikethrough": false,
            "obfuscated": false
        }
    }

    function clone(value) {
        return JSON.parse(JSON.stringify(value))
    }

    function clearSegments() {
        segmentModel.clear()
    }

    // Segment text is stored as the real Minecraft text.  The visual editor
    // shows control characters with JSON-style escapes, so `\\n` remains a
    // visible, editable token instead of becoming an empty-looking line.
    function textForEditor(value) {
        return String(value === undefined || value === null ? "" : value)
                .replace(/\\/g, "\\\\")
                .replace(/\n/g, "\\n")
                .replace(/\r/g, "\\r")
                .replace(/\t/g, "\\t")
    }

    function textFromEditor(value) {
        return String(value === undefined || value === null ? "" : value)
                .replace(/\\(.)/g, function(match, escaped) {
                    if (escaped === "n")
                        return "\n"
                    if (escaped === "r")
                        return "\r"
                    if (escaped === "t")
                        return "\t"
                    if (escaped === "\\")
                        return "\\"
                    return match
                })
    }

    function appendSegment(segment) {
        var clean = defaultSegment(segment.text)
        clean.color = segment.color || "white"
        clean.bold = !!segment.bold
        clean.italic = !!segment.italic
        clean.underlined = !!segment.underlined
        clean.strikethrough = !!segment.strikethrough
        clean.obfuscated = !!segment.obfuscated
        segmentModel.append(clean)
    }

    function loadJson(source) {
        clearSegments()
        parseError = ""
        var input = source === undefined || source === null ? "" : String(source).trim()
        if (!input.length) {
            appendSegment(defaultSegment(""))
            return
        }

        var parsed
        try {
            parsed = JSON.parse(input)
        } catch (error) {
            parseError = "原文本不是有效 JSON；已创建空白文本组件。取消即可保留原内容。"
            appendSegment(defaultSegment(""))
            return
        }

        var unsupported = false
        function appendComponent(component, inherited) {
            if (Array.isArray(component)) {
                // In Java Edition a text-component array is shorthand for a
                // component followed by its extra children, so each entry
                // inherits the effective style of the preceding one.
                var arrayStyle = clone(inherited)
                for (var arrayIndex = 0; arrayIndex < component.length; ++arrayIndex)
                    arrayStyle = appendComponent(component[arrayIndex], arrayStyle)
                return arrayStyle
            }
            var style = clone(inherited)
            if (typeof component === "string" || typeof component === "number") {
                style.text = String(component)
                appendSegment(style)
                return style
            }
            if (!component || typeof component !== "object") {
                unsupported = true
                return style
            }
            if (component.translate !== undefined || component.keybind !== undefined
                    || component.score !== undefined || component.selector !== undefined
                    || component.nbt !== undefined) {
                unsupported = true
                return style
            }
            var keys = ["color", "bold", "italic", "underlined", "strikethrough", "obfuscated"]
            for (var keyIndex = 0; keyIndex < keys.length; ++keyIndex) {
                var key = keys[keyIndex]
                if (component[key] !== undefined)
                    style[key] = component[key]
            }
            style.text = component.text === undefined ? "" : String(component.text)
            appendSegment(style)
            if (component.extra !== undefined)
                appendComponent(component.extra, style)
            return style
        }

        appendComponent(parsed, defaultSegment(""))
        if (unsupported) {
            clearSegments()
            appendSegment(defaultSegment(""))
            parseError = "该 JSON 使用了 translate、selector、score、nbt 等高级文本组件，当前可视化编辑器不会保留这些字段。"
        } else if (!segmentModel.count) {
            appendSegment(defaultSegment(""))
        }
    }

    function updateSegment(index, key, value) {
        if (index >= 0 && index < segmentModel.count)
            segmentModel.setProperty(index, key, value)
    }

    function moveSegment(index, offset) {
        var target = index + offset
        if (target >= 0 && target < segmentModel.count)
            segmentModel.move(index, target, 1)
    }

    function removeSegment(index) {
        if (segmentModel.count > 1)
            segmentModel.remove(index)
    }

    function addSegment(afterIndex) {
        var segment = defaultSegment("文字")
        if (afterIndex >= 0 && afterIndex < segmentModel.count) {
            var previous = segmentModel.get(afterIndex)
            segment.color = previous.color
        }
        segmentModel.insert(Math.max(0, afterIndex + 1), segment)
    }

    function styleForSegment(segment) {
        return {
            "color": segment.color,
            "bold": !!segment.bold,
            "italic": !!segment.italic,
            "underlined": !!segment.underlined,
            "strikethrough": !!segment.strikethrough,
            "obfuscated": !!segment.obfuscated
        }
    }

    function jsonForSegment(segment, includeExtra, inheritedStyle) {
        var result = { "text": segment.text }
        var style = styleForSegment(segment)
        var inherited = inheritedStyle || {
            "color": "white", "bold": false, "italic": false, "underlined": false,
            "strikethrough": false, "obfuscated": false
        }
        // A field is emitted only when it changes the vanilla/default inherited
        // value. This keeps generated JSON compact while still allowing a child
        // component to explicitly turn an inherited style off.
        if (style.color !== inherited.color)
            result.color = style.color
        var styleKeys = ["bold", "italic", "underlined", "strikethrough", "obfuscated"]
        for (var styleIndex = 0; styleIndex < styleKeys.length; ++styleIndex) {
            var styleKey = styleKeys[styleIndex]
            if (style[styleKey] !== inherited[styleKey])
                result[styleKey] = style[styleKey]
        }
        if (includeExtra && segmentModel.count > 1) {
            result.extra = []
            for (var childIndex = 1; childIndex < segmentModel.count; ++childIndex)
                result.extra.push(jsonForSegment(segmentModel.get(childIndex), false, style))
        }
        return result
    }

    function exportedJson() {
        if (!segmentModel.count)
            return JSON.stringify(defaultSegment(""))
        if (segmentModel.count === 1)
            return JSON.stringify(jsonForSegment(segmentModel.get(0), false, null))

        // Use Java Edition's component-list shorthand. It reads naturally as
        // successive text blocks and is equivalent to nesting later blocks in
        // `extra`, while remaining valid for 1.14 and newer.
        var components = []
        var inheritedStyle = null
        for (var componentIndex = 0; componentIndex < segmentModel.count; ++componentIndex) {
            var segment = segmentModel.get(componentIndex)
            components.push(jsonForSegment(segment, false, inheritedStyle))
            inheritedStyle = styleForSegment(segment)
        }
        return JSON.stringify(components)
    }

    function previewColor(segment) {
        var value = segment.color
        for (var colorIndex = 0; colorIndex < colorOptions.length; ++colorIndex) {
            if (colorOptions[colorIndex].value === value)
                return colorOptions[colorIndex].preview
        }
        return value.length ? value : "#ffffff"
    }

    function escapeHtml(value) {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                            .replace(/>/g, "&gt;").replace(/\"/g, "&quot;")
                            .replace(/'/g, "&#39;").replace(/\n/g, "<br>")
    }

    function previewRichText() {
        var result = ""
        for (var index = 0; index < segmentModel.count; ++index) {
            var segment = segmentModel.get(index)
            var decorations = []
            if (segment.underlined)
                decorations.push("underline")
            if (segment.strikethrough)
                decorations.push("line-through")
            var style = "color:" + previewColor(segment)
                    + ";font-weight:" + (segment.bold ? "bold" : "normal")
                    + ";font-style:" + (segment.italic ? "italic" : "normal")
            if (decorations.length)
                style += ";text-decoration:" + decorations.join(" ")
            result += "<span style=\"" + style + "\">" + escapeHtml(segment.text) + "</span>"
        }
        return result
    }

    onAboutToOpen: {
        loadJson(jsonText)
    }

    Rectangle {
        x: 24; y: 74; width: parent.width * 0.61 - 34; height: parent.height - 144
        radius: 10; color: Colors.changeA(Colors.card, 0.50)
        border.width: 1; border.color: Colors.changeA(Colors.outline, 0.08)

        XCText { x: 14; y: 12; xcText: "文本片段"; onCenter: false; xcFontSize: 15 }
        TextButton {
            anchors.right: parent.right; anchors.rightMargin: 10; y: 8
            text: "+ 添加片段"; height: 27; radius: 6; textSize: 12; boldFont: false; widthBorderSize: 8
            buttonColor: Colors.changeA(Colors.border, 0.24); firedColor: Colors.changeA(Colors.border, 0.40); pressedColor: Colors.changeA(Colors.border, 0.55)
            onClicked: root.addSegment(segmentModel.count - 1)
        }
        XCText {
            x: 14; y: 37; width: parent.width - 28; xcText: root.parseError
            visible: root.parseError.length > 0; onCenter: false; xcWrapMode: true; xcFontSize: 11; boldFont: false; textColor: Colors.error
        }

        ListView {
            id: segmentList
            x: 8; y: root.parseError.length ? 72 : 48
            width: parent.width - 34; height: parent.height - y - 8
            clip: true; spacing: 8; model: segmentModel
            Controls.ScrollBar.vertical: XCScrollBar {}
            delegate: Rectangle {
                id: segmentCard
                required property int index
                required property var model
                width: segmentList.width
                height: 166
                radius: 8
                color: Colors.changeA(Colors.background, 0.42)
                border.width: 1
                border.color: Colors.changeA(Colors.outline, 0.10)

                XCText { x: 10; y: 9; xcText: "片段 " + (segmentCard.index + 1); onCenter: false; xcFontSize: 12; textColor: Colors.banned; boldFont: false }
                ActionButton {
                    destructive: true

                    x: parent.width - width - 8; y: 6; height: 24; radius: 5; text: "删除"; textSize: 11; boldFont: false; widthBorderSize: 7
                    enabled: segmentModel.count > 1
                    onClicked: root.removeSegment(segmentCard.index)
                }

                XCTextField {
                    id: segmentTextInput
                    x: 10; y: 34; width: parent.width - 20; height: 32
                    text: root.textForEditor(segmentCard.model.text)
                    placeholderText: "输入文字"
                    onTextEdited: root.updateSegment(segmentCard.index, "text", root.textFromEditor(text))
                }

                TextStyleEditor {
                    id: segmentStyleEditor
                    x: 10
                    y: 76
                    colorOptions: root.colorOptions
                    color: segmentCard.model.color
                    bold: !!segmentCard.model.bold
                    italic: !!segmentCard.model.italic
                    underlined: !!segmentCard.model.underlined
                    strikethrough: !!segmentCard.model.strikethrough
                    obfuscated: !!segmentCard.model.obfuscated
                    onPropertyEdited: {
                        root.updateSegment(segmentCard.index, "color", segmentStyleEditor.color)
                        root.updateSegment(segmentCard.index, "bold", segmentStyleEditor.bold)
                        root.updateSegment(segmentCard.index, "italic", segmentStyleEditor.italic)
                        root.updateSegment(segmentCard.index, "underlined", segmentStyleEditor.underlined)
                        root.updateSegment(segmentCard.index, "strikethrough", segmentStyleEditor.strikethrough)
                        root.updateSegment(segmentCard.index, "obfuscated", segmentStyleEditor.obfuscated)
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 9; y: 134; spacing: 4
                    TextButton { text: "↑"; height: 23; radius: 5; textSize: 12; widthBorderSize: 7; enabled: segmentCard.index > 0; buttonColor: Colors.pressed; onClicked: root.moveSegment(segmentCard.index, -1) }
                    TextButton { text: "↓"; height: 23; radius: 5; textSize: 12; widthBorderSize: 7; enabled: segmentCard.index < segmentModel.count - 1; buttonColor: Colors.pressed; onClicked: root.moveSegment(segmentCard.index, 1) }
                    TextButton { text: "+"; height: 23; radius: 5; textSize: 13; widthBorderSize: 7; buttonColor: Colors.pressed; onClicked: root.addSegment(segmentCard.index) }
                }
            }
        }
    }

    Rectangle {
        x: parent.width * 0.61; y: 74; width: parent.width * 0.39 - 24; height: parent.height - 144
        radius: 10; color: Colors.changeA(Colors.card, 0.50)
        border.width: 1; border.color: Colors.changeA(Colors.outline, 0.08)

        XCText { x: 14; y: 12; xcText: "效果预览"; onCenter: false; xcFontSize: 15 }
        Rectangle {
            x: 12; y: 42; width: parent.width - 24; height: 112; radius: 7
            color: "#24262e"; border.width: 1; border.color: Colors.changeA(Colors.outline, 0.12)
            Flickable {
                id: previewFlickable
                anchors.fill: parent; anchors.margins: 10
                contentWidth: width; contentHeight: previewText.height
                clip: true
                Text {
                    id: previewText
                    width: previewFlickable.width
                    text: root.previewRichText()
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "Microsoft YaHei"
                }
            }
        }
        XCText { x: 14; y: 170; xcText: "导出的 JSON"; onCenter: false; xcFontSize: 14 }
        XCScrollView {
            id: jsonPreviewViewport
            x: 12; y: 198; width: parent.width - 24
            height: Math.max(0, parent.height - y - 12)
            XCTextArea {
                id: jsonPreview
                height: Math.max(jsonPreviewViewport.availableHeight, implicitHeight)
                readOnly: true; selectByMouse: true; wrapMode: TextEdit.WrapAnywhere
                text: root.exportedJson()
                editorFontSize: 12
            }
        }
    }
    actions: [
        ActionButton { text: "取消"; widthBorderSize: 12
            onClicked: root.close(null) },
        ActionButton {
            primary: true
            text: "应用到文本框"; widthBorderSize: 12
            onClicked: root.close({ "jsonText": root.exportedJson() }) }
    ]
}
