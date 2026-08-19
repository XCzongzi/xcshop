import QtQuick
import xcshop

// Minecraft text color and decoration editor. The owning view reads the
// complete state whenever propertyEdited is emitted.
Item {
    id: root

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
    property string color: "white"
    property string customColor: ""
    property bool bold: false
    property bool italic: false
    property bool underlined: false
    property bool strikethrough: false
    property bool obfuscated: false
    property bool showObfuscated: true

    signal propertyEdited()

    implicitWidth: Math.max(colorRow.width, formatRow.width)
    implicitHeight: formatRow.y + formatRow.height
    width: implicitWidth
    height: implicitHeight

    Row {
        id: colorRow
        spacing: 4

        Repeater {
            model: root.colorOptions

            delegate: Rectangle {
                required property var modelData

                width: 17
                height: 17
                radius: 4
                color: modelData.preview
                border.width: root.color === modelData.value && !root.customColor.length ? 2 : 1
                border.color: root.color === modelData.value && !root.customColor.length
                              ? Colors.border : Colors.changeA(Colors.text, 0.30)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.color = modelData.value
                        root.customColor = ""
                        root.propertyEdited()
                    }
                }
            }
        }
    }

    XCTextField {
        id: customColorInput
        y: colorRow.height + 8
        width: 100
        height: 28
        text: root.customColor
        placeholderText: "#RRGGBB"
        font.pixelSize: 12
        onTextEdited: {
            root.customColor = text
            root.propertyEdited()
        }
    }

    Row {
        id: formatRow
        x: customColorInput.width + 8
        y: customColorInput.y
        spacing: 4

        BooleanSwitch {
            label: "粗"
            checked: root.bold
            onToggled: function(value) {
                root.bold = value
                root.propertyEdited()
            }
        }
        BooleanSwitch {
            label: "斜"
            checked: root.italic
            onToggled: function(value) {
                root.italic = value
                root.propertyEdited()
            }
        }
        BooleanSwitch {
            label: "下"
            checked: root.underlined
            onToggled: function(value) {
                root.underlined = value
                root.propertyEdited()
            }
        }
        BooleanSwitch {
            label: "删"
            checked: root.strikethrough
            onToggled: function(value) {
                root.strikethrough = value
                root.propertyEdited()
            }
        }
        BooleanSwitch {
            visible: root.showObfuscated
            label: "乱"
            checked: root.obfuscated
            onToggled: function(value) {
                root.obfuscated = value
                root.propertyEdited()
            }
        }
    }
}
