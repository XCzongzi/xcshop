pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import "../../../js/MinecraftTextColors.js" as MinecraftTextColors

Item {
    id: root
    property string color: "white"
    property var colorOptions: MinecraftTextColors.colors
    property int swatchSize: 24
    property alias colorInput: colorInput
    readonly property var options: colorOptions.concat(Global.customTextColors.map(function(value) {
        return {value: value, preview: value, custom: true}
    }))
    readonly property bool canAdd: /^#[0-9a-fA-F]{6}$/.test(colorInput.text)
                                   && Global.customTextColors.indexOf(colorInput.text.toLowerCase()) < 0
                                   && !isGameColor(colorInput.text)
    signal colorEdited(string value)
    implicitWidth: 460
    implicitHeight: paletteFlow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function isGameColor(value) {
        return colorOptions.some(function(option) {
            return option.value === value || option.preview.toLowerCase() === value.toLowerCase()
        })
    }
    function displayColor(value) {
        for (var option of colorOptions) {
            if (option.value === value || option.preview.toLowerCase() === value.toLowerCase())
                return option.value
        }
        return value
    }
    function isValid(value) { return /^#[0-9a-fA-F]{6}$/.test(value) || isGameColor(value) }
    function managementItems(value) {
        var index = Global.customTextColors.indexOf(value)
        return [
            {text: "载入色值", action: function() {
                root.colorEdited(value)
                colorInput.forceActiveFocus()
                colorInput.selectAll()
            }},
            {text: "用输入框颜色替换", enabled: root.canAdd, action: function() {
                Global.replaceTextColor(value, colorInput.text)
            }},
            {separator: true},
            {text: "前移", enabled: index > 0, action: function() { Global.moveTextColor(value, -1) }},
            {text: "后移", enabled: index >= 0 && index < Global.customTextColors.length - 1,
                action: function() { Global.moveTextColor(value, 1) }},
            {separator: true},
            {text: "删除预设", action: function() { Global.removeTextColor(value) }}
        ]
    }
    Flow {
        id: paletteFlow
        width: root.width
        spacing: 5
        Repeater {
            model: root.options
            delegate: Rectangle {
                id: swatch
                required property var modelData
                objectName: "richTextColor_" + modelData.value
                width: root.swatchSize
                height: width
                radius: 4
                color: modelData.preview
                border.width: root.displayColor(root.color) === root.displayColor(modelData.value) ? 2 : 1
                border.color: border.width === 2 ? Colors.border : Colors.changeA(Colors.text, 0.24)
                MouseArea {
                    id: swatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) root.colorEdited(swatch.modelData.value)
                        else if (swatch.modelData.custom)
                            SignalBus.contextMenuRequested(swatch, mouse.x, mouse.y,
                                                           root.managementItems(swatch.modelData.value), null)
                    }
                }
                XCToolTip {
                    objectName: "textColorToolTip"
                    active: swatchMouse.containsMouse
                    text: swatch.modelData.value
                }
            }
        }
        Row {
            spacing: 5
            XCTextField {
                id: colorInput
                objectName: "richTextCustomColor"
                width: 112
                height: root.swatchSize
                editorFontSize: 12
                placeholderText: "#RRGGBB"
                text: root.displayColor(root.color)
                maximumLength: 16
                onTextEdited: if (root.isValid(text)) root.colorEdited(root.displayColor(text))
                onAccepted: if (root.isValid(text)) root.colorEdited(root.displayColor(text))
            }
            TextButton {
                id: addColor
                objectName: "addTextColorPreset"
                text: "+"
                width: root.swatchSize; height: width
                radius: 4; textSize: 17; boldFont: false
                enabled: root.canAdd
                buttonColor: Colors.changeA(Colors.border, 0.16)
                onClicked: Global.addTextColor(colorInput.text)
                XCToolTip { active: addColor.hovered; text: "添加到颜色预设" }
            }
        }
    }
}
