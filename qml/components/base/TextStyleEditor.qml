pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import "../../../js/MinecraftTextColors.js" as MinecraftTextColors

Item {
    id: root
    property var colorOptions: MinecraftTextColors.colors
    property string color: "white"
    property bool bold: false
    property bool italic: false
    property bool underlined: false
    property bool strikethrough: false
    property bool obfuscated: false
    property bool showObfuscated: true
    signal propertyEdited

    readonly property bool stacked: width < 600
    implicitWidth: 360
    implicitHeight: stacked ? palette.height + formatRow.height + 8 : Math.max(palette.height, formatRow.height)
    width: implicitWidth
    height: implicitHeight
    TextColorPalette {
        id: palette
        width: root.stacked ? root.width : Math.max(0, root.width - formatRow.width - 16)
        swatchSize: 17
        colorOptions: root.colorOptions
        color: root.color
        onColorEdited: function(value) {
            root.color = value
            root.propertyEdited()
        }
    }
    Row {
        id: formatRow
        x: parent.width - width
        y: root.stacked ? palette.height + 8 : 0
        spacing: 4
        Repeater {
            model: [
                {key: "bold", label: "粗", tip: "粗体"},
                {key: "italic", label: "斜", tip: "斜体"},
                {key: "underlined", label: "下", tip: "下划线"},
                {key: "strikethrough", label: "删", tip: "删除线"}
            ].concat(root.showObfuscated ? [{key: "obfuscated", label: "乱", tip: "混淆"}] : [])
            delegate: BooleanSwitch {
                id: toggle
                required property var modelData
                label: modelData.label
                checked: root[modelData.key]
                onToggled: function(value) {
                    root[toggle.modelData.key] = value
                    root.propertyEdited()
                }
                XCToolTip { active: toggle.hovered; text: toggle.modelData.tip }
            }
        }
    }
}
