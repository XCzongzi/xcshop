pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import "../../../js/MinecraftTextColors.js" as MinecraftTextColors

// Minecraft text color and decoration editor. The owning view reads the
// complete state whenever propertyEdited is emitted.
Item {
    id: root

    property var colorOptions: MinecraftTextColors.colors
    property string color: "white"
    // UI-only fallback used when the custom-colour field is cleared.  The
    // persisted/editor API remains the single `color` property.
    property string lastPresetColor: "white"
    property bool bold: false
    property bool italic: false
    property bool underlined: false
    property bool strikethrough: false
    property bool obfuscated: false
    property bool showObfuscated: true

    signal propertyEdited

    implicitWidth: Math.max(colorRow.width, formatRow.width)
    implicitHeight: formatRow.y + formatRow.height
    width: implicitWidth
    height: implicitHeight

    function isPresetColor(value) {
        for (var index = 0; index < colorOptions.length; ++index) {
            if (colorOptions[index].value === value)
                return true
        }
        return false
    }

    onColorChanged: {
        if (isPresetColor(color))
            lastPresetColor = color
    }

    Row {
        id: colorRow
        spacing: 4

        Repeater {
            model: root.colorOptions

            delegate: Rectangle {
                id: colorSwatch
                required property var modelData

                width: 17
                height: 17
                radius: 4
                color: modelData.preview
                border.width: root.color === modelData.value ? 2 : 1
                border.color: root.color === modelData.value
                              ? Colors.border : Colors.changeA(Colors.text, 0.30)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.color = colorSwatch.modelData.value
                        root.propertyEdited()
                    }
                }
            }
        }
    }

    XCTextField {
        id: colorInput
        y: colorRow.height + 8
        width: 100
        height: 28
        text: root.isPresetColor(root.color) ? "" : root.color
        placeholderText: "#RRGGBB"
        font.pixelSize: 12
        onTextEdited: {
            root.color = text.length ? text : root.lastPresetColor
            root.propertyEdited()
        }
    }

    Row {
        id: formatRow
        x: colorInput.width + 8
        y: colorInput.y
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
