pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

// Visual editor for Minecraft JSON text components. It intentionally exports
// ordinary { text, color, ... , extra } components so the result can be used
// directly in tellraw/title style fields.
Item {
    id: root
    anchors.fill: parent

    property string title: "编辑 JSON 文本"
    property string jsonText: ""
    property string parseError: ""
    property var colorOptions: [
        { "name": "黑", "value": "black", "preview": "#000000" },
        { "name": "深蓝", "value": "dark_blue", "preview": "#0000aa" },
        { "name": "深绿", "value": "dark_green", "preview": "#00aa00" },
        { "name": "深青", "value": "dark_aqua", "preview": "#00aaaa" },
        { "name": "深红", "value": "dark_red", "preview": "#aa0000" },
        { "name": "深紫", "value": "dark_purple", "preview": "#aa00aa" },
        { "name": "金", "value": "gold", "preview": "#ffaa00" },
        { "name": "灰", "value": "gray", "preview": "#aaaaaa" },
        { "name": "深灰", "value": "dark_gray", "preview": "#555555" },
        { "name": "蓝", "value": "blue", "preview": "#5555ff" },
        { "name": "绿", "value": "green", "preview": "#55ff55" },
        { "name": "青", "value": "aqua", "preview": "#55ffff" },
        { "name": "红", "value": "red", "preview": "#ff5555" },
        { "name": "浅紫", "value": "light_purple", "preview": "#ff55ff" },
        { "name": "黄", "value": "yellow", "preview": "#ffff55" },
        { "name": "白", "value": "white", "preview": "#ffffff" }
    ]

    signal closed(var result)

    ListModel { id: segmentModel }

    readonly property int dialogWidth: Math.min(1040, Math.max(660, width - 48))
    readonly property int dialogHeight: Math.min(720, Math.max(520, height - 48))

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

    function open() {
        scrim.opacity = 0
        dialog.opacity = 0
        dialog.scale = 0.97
        loadJson(jsonText)
        openAnimation.restart()
    }

    function close(result) {
        if (closeAnimation.running)
            return
        root.closeResult = result
        closeAnimation.restart()
    }

    property var closeResult: null

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        MouseArea { anchors.fill: parent; hoverEnabled: true }
    }

    Rectangle {
        id: dialog
        width: root.dialogWidth
        height: root.dialogHeight
        anchors.centerIn: parent
        radius: 15
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.99)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.14)
        transformOrigin: Item.Center
        opacity: 0

        layer.enabled: true
        layer.effect: XCShadow { shadowColor: "#a8000000"; shadowBlur: 0.85; shadowVerticalOffset: 10 }

        Rectangle { width: parent.width; height: 5; radius: 15; color: Colors.border }

        XCText { x: 24; y: 22; xcText: root.title; onCenter: false; xcFontSize: 21 }
        XCText {
            x: 24; y: 51; width: parent.width - 48
            xcText: "按片段编写 Minecraft 文本组件：颜色、粗体、斜体、下划线、删除线和随机字符都会导出为标准 JSON。"
            onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned
        }

        Rectangle { x: 24; y: 78; width: parent.width - 48; height: 1; color: Colors.changeA(Colors.text, 0.10) }

        Rectangle {
            x: 24; y: 94; width: parent.width * 0.61 - 34; height: parent.height - 164
            radius: 10; color: Colors.changeA(Colors.foreground, 0.50)
            border.width: 1; border.color: Colors.changeA(Colors.text, 0.08)

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
                delegate: Rectangle {
                    id: segmentCard
                    required property int index
                    required property var model
                    width: segmentList.width
                    height: 166
                    radius: 8
                    color: Colors.changeA(Colors.background, 0.42)
                    border.width: 1
                    border.color: Colors.changeA(Colors.text, 0.10)

                    XCText { x: 10; y: 9; xcText: "片段 " + (segmentCard.index + 1); onCenter: false; xcFontSize: 12; textColor: Colors.banned; boldFont: false }
                    TextButton {
                        x: parent.width - width - 8; y: 6; height: 24; radius: 5; text: "删除"; textSize: 11; boldFont: false; widthBorderSize: 7
                        enabled: segmentModel.count > 1; buttonColor: Colors.changeA(Colors.error, 0.18); firedColor: Colors.changeA(Colors.error, 0.32); pressedColor: Colors.changeA(Colors.error, 0.48)
                        onClicked: root.removeSegment(segmentCard.index)
                    }

                    XCTextField {
                        id: segmentTextInput
                        x: 10; y: 34; width: parent.width - 20; height: 32
                        text: root.textForEditor(segmentCard.model.text)
                        placeholderText: "输入文字；\\n 换行，\\\\n 显示 \\n"
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
            ScrollBar {
                id: segmentScrollBar
                x: segmentList.x + segmentList.width + 8
                y: segmentList.y
                height: segmentList.height
                content_height: segmentList.contentHeight
                layout_determines: segmentModel.count
                animatePosition: false
                z: 5
                onHeight_outputChanged: {
                    if (Math.abs(segmentList.contentY - height_output) > 0.5)
                        segmentList.contentY = height_output
                }
            }
            Connections {
                target: segmentList
                function onContentYChanged() {
                    segmentScrollBar.setContentOffset(segmentList.contentY)
                }
            }
        }

        Rectangle {
            x: parent.width * 0.61; y: 94; width: parent.width * 0.39 - 24; height: parent.height - 164
            radius: 10; color: Colors.changeA(Colors.foreground, 0.50)
            border.width: 1; border.color: Colors.changeA(Colors.text, 0.08)

            XCText { x: 14; y: 12; xcText: "效果预览"; onCenter: false; xcFontSize: 15 }
            Rectangle {
                x: 12; y: 42; width: parent.width - 24; height: 112; radius: 7
                color: "#24262e"; border.width: 1; border.color: Colors.changeA(Colors.text, 0.12)
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
            Controls.TextArea {
                id: jsonPreview
                x: 12; y: 198; width: parent.width - 38; height: parent.height - y - 12
                readOnly: true; selectByMouse: true; wrapMode: TextEdit.WrapAnywhere
                text: root.exportedJson()
                color: Colors.text; font.family: "Consolas"; font.pixelSize: 12
                background: Rectangle { radius: 7; color: Colors.changeA(Colors.background, 0.55); border.width: 1; border.color: Colors.changeA(Colors.text, 0.10) }
            }
            ScrollBar {
                id: jsonPreviewScrollBar
                x: jsonPreview.x + jsonPreview.width + 8
                y: jsonPreview.y + 3
                height: jsonPreview.height - 6
                content_height: jsonPreview.contentHeight
                layout_determines: segmentModel.count
                animatePosition: false
                z: 3
                onHeight_outputChanged: {
                    if (Math.abs(jsonPreview.contentY - height_output) > 0.5)
                        jsonPreview.contentY = height_output
                }
            }
            Connections {
                target: jsonPreview
                function onContentYChanged() {
                    jsonPreviewScrollBar.setContentOffset(jsonPreview.contentY)
                }
            }
        }

        Row {
            anchors.right: parent.right; anchors.rightMargin: 22; anchors.bottom: parent.bottom; anchors.bottomMargin: 17; spacing: 8
            TextButton { text: "取消"; height: 34; radius: 7; textSize: 13; widthBorderSize: 12; buttonColor: Colors.pressed; onClicked: root.close(null) }
            TextButton { text: "应用到文本框"; height: 34; radius: 7; textSize: 13; widthBorderSize: 12; buttonColor: Colors.changeA(Colors.border, 0.72); firedColor: Colors.changeA(Colors.border, 0.88); pressedColor: Colors.border; textColor: "#1b1b1b"; onClicked: root.close({ "jsonText": root.exportedJson() }) }
        }
    }

    ParallelAnimation {
        id: openAnimation
        PropertyAnimation { target: scrim; property: "opacity"; to: 0.46; duration: 180; easing.type: Easing.OutCubic }
        PropertyAnimation { target: dialog; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        PropertyAnimation { target: dialog; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
    }
    ParallelAnimation {
        id: closeAnimation
        PropertyAnimation { target: scrim; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
        PropertyAnimation { target: dialog; property: "opacity"; to: 0; duration: 130; easing.type: Easing.InCubic }
        PropertyAnimation { target: dialog; property: "scale"; to: 0.97; duration: 150; easing.type: Easing.InCubic }
        onFinished: root.closed(root.closeResult)
    }
}
