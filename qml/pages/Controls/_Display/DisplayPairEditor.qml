import QtQuick
import xcshop

Item {
    id: root
    property var value: null
    property string firstKey: "cost"
    property string secondKey: "value"
    property string firstLabel: "代价名称"
    property string secondLabel: "数量"
    property bool editSecondStyle: true
    property var orders: ["cost_then_value", "value_then_cost"]
    readonly property var propertyKeys: ["head", firstKey, "middle"].concat(editSecondStyle ? [secondKey, "end"] : ["end"])
    readonly property bool editingStyle: selectedProperty() === firstKey || selectedProperty() === secondKey
    property bool loading: false
    property bool ready: false
    readonly property bool resizing: textEditor.resizing
    signal edited
    height: fields.height
    function selectedProperty() {
        return propertyKeys[tabs.selected] || "";
    }
    function load() {
        if (!value || !ready)
            return;
        loading = true;
        order.selected = Math.max(0, orders.indexOf(value.order));
        loadProperty();
        loading = false;
    }
    function loadProperty() {
        if (!value || tabs.selected < 0)
            return;
        var key = selectedProperty();
        if (key === firstKey || key === secondKey) {
            var data = value[key];
            style.color = data.color;
            style.bold = data.bold;
            style.italic = data.italic;
            style.underlined = data.underlined;
            style.strikethrough = data.strikethrough;
            style.obfuscated = data.obfuscated;
        } else
            textEditor.setContent(value[key]);
    }
    onValueChanged: load()
    Component.onCompleted: {
        ready = true;
        load();
    }
    Column {
        id: fields
        width: parent.width
        spacing: 12
        RadioGroup {
            id: order
            options: [root.firstLabel + " + " + root.secondLabel, root.secondLabel + " + " + root.firstLabel]
            onClicked: {
                if (root.value) {
                    root.value.order = root.orders[selected];
                    root.edited();
                }
            }
        }
        MultiPropertyEdit {
            id: tabs
            objectName: "pairProperties"
            width: parent.width
            options: ["项头文本", root.firstLabel, "项中文本"].concat(root.editSecondStyle ? [root.secondLabel, "项尾文本"] : ["项尾文本"])
            onSelectedChanged: root.loadProperty()
            DisplayTextEditor {
                id: textEditor
                width: parent.width
                visible: !root.editingStyle
                onEdited: function (text) {
                    if (root.loading || !root.value)
                        return;
                    root.value[root.selectedProperty()] = text;
                    root.edited();
                }
            }
            Item {
                width: parent.width
                height: style.height + 36
                visible: root.editingStyle
                TextStyleEditor {
                    id: style
                    objectName: "pairTextStyle"
                    onPropertyEdited: {
                        if (root.loading || !root.value)
                            return;
                        root.value[root.selectedProperty()] = {
                            color: color,
                            bold: bold,
                            italic: italic,
                            underlined: underlined,
                            strikethrough: strikethrough,
                            obfuscated: obfuscated
                        };
                        root.edited();
                    }
                }
                TextButton {
                    y: style.height + 8
                    height: 28
                    textSize: 12
                    text: "清除样式"
                    textColor: Colors.banned
                    onClicked: {
                        root.value[root.selectedProperty()] = {
                            color: "",
                            bold: false,
                            italic: false,
                            underlined: false,
                            strikethrough: false,
                            obfuscated: false
                        };
                        root.loadProperty();
                        root.edited();
                    }
                }
            }
        }
    }
}
