import QtQuick
import xcshop

// 操作内部的触发与执行编辑器。
Item {
    id: root
    required property var modelData
    property int revision: 0
    signal updateData
    implicitHeight: fields.height
    height: implicitHeight
    function changed() {
        revision++;
        updateData();
    }
    function loadExecutionValue() {
        var execution = modelData.execute;
        commandInput.text = execution.kind === "command" ? execution.value || "" : "";
        functionInput.setContent(execution.kind === "function" ? execution.value || "" : "");
    }
    function load() {
        triggerKind.selected = modelData.mode.kind === "drop_item" ? 1 : 0;
        dropQuantity.selected = modelData.mode.quantity === "all" ? 1 : 0;
        var filter = modelData.mode.filter || {
            kind: "none"
        };
        filterKind.value = ["none", "quantity", "slot"].indexOf(filter.kind) >= 0 ? filter.kind : "none";
        quantityMode.value = ["all", "less_than_all", "custom"].indexOf(filter.mode) >= 0 ? filter.mode : "all";
        executeKind.selected = Math.max(0, ["grant_item", "command", "function"].indexOf(modelData.execute.kind));
        loadExecutionValue();
        revision++;
    }
    Component.onCompleted: load()
    Column {
        id: fields
        width: parent.width
        spacing: 12
        RadioGroup {
            id: triggerKind
            objectName: "triggerKind"
            text: "触发方式"
            options: ["取得商品", "掷出商品"]
            onClicked: {
                root.modelData.mode = selected === 0 ? {
                    kind: "take_item",
                    filter: {
                        kind: "none"
                    }
                } : {
                    kind: "drop_item",
                    quantity: "single"
                };
                filterKind.value = "none";
                dropQuantity.selected = 0;
                root.changed();
            }
        }
        RadioGroup {
            id: dropQuantity
            visible: triggerKind.selected === 1
            text: "掷出数量"
            options: ["单个商品", "整组商品"]
            onClicked: {
                root.modelData.mode.quantity = selected === 0 ? "single" : "all";
                root.changed();
            }
        }
        Flow {
            visible: triggerKind.selected === 0
            width: parent.width
            spacing: 8
            z: 3
            XCComboBox {
                id: filterKind
                height: 32
                options: [{value: "none", label: "无筛选"}, {value: "quantity", label: "数量筛选"}, {value: "slot", label: "栏位筛选"}]
                onValueActivated: function(value) {
                    filterKind.value = value;
                    root.modelData.mode.filter = value === "quantity" ? {
                        kind: "quantity",
                        mode: "all"
                    } : value === "slot" ? {
                        kind: "slot",
                        slot: "0"
                    } : {
                        kind: "none"
                    };
                    quantityMode.value = "all";
                    root.changed();
                }
            }
            XCComboBox {
                id: quantityMode
                height: 32
                visible: filterKind.value === "quantity"
                options: [{value: "all", label: "全部（左键）"}, {value: "less_than_all", label: "少于全部（右键）"}, {value: "custom", label: "自定义"}]
                onValueActivated: function(value) {
                    quantityMode.value = value;
                    root.modelData.mode.filter = {
                        kind: "quantity",
                        mode: value
                    };
                    if (value === "custom")
                        root.modelData.mode.filter.amount = "1";
                    root.changed();
                }
            }
            XCTextField {
                objectName: "triggerAmount"
                visible: filterKind.value === "quantity" && quantityMode.value === "custom"
                width: Math.min(160, fields.width)
                highlightMacros: true
                placeholderText: "数量或 {{宏}}"
                text: {
                    root.revision;
                    return (root.modelData.mode.filter || {}).amount || "";
                }
                onEditingFinished: {
                    root.modelData.mode.filter.amount = text;
                    root.changed();
                }
            }
            XCTextField {
                objectName: "triggerSlot"
                visible: filterKind.value === "slot"
                width: Math.min(160, fields.width)
                placeholderText: "栏位编号"
                text: {
                    root.revision;
                    var f = root.modelData.mode.filter;
                    return f && f.slot !== undefined ? String(f.slot) : "";
                }
                onEditingFinished: {
                    root.modelData.mode.filter.slot = text;
                    root.changed();
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Colors.changeA(Colors.outline, 0.08)
        }
        RadioGroup {
            id: executeKind
            objectName: "executeKind"
            text: "执行内容"
            options: ["获得物品", "执行指令", "执行函数"]
            onClicked: {
                root.modelData.execute = selected === 0 ? {
                    kind: "grant_item"
                } : {
                    kind: selected === 1 ? "command" : "function",
                    value: ""
                };
                root.loadExecutionValue();
                root.changed();
            }
        }
        AnimatedReveal {
            id: executePanel
            objectName: "executePanel"
            width: parent.width
            expanded: executeKind.selected > 0
            contentHeight: (executeKind.selected === 1 ? commandInput.height : functionInput.height) + 8
            contentAnimating: functionInput.resizing
            XCTextField {
                id: commandInput
                objectName: "operationCommandValue"
                visible: executeKind.selected === 1
                x: 8
                y: 4
                width: parent.width - 16
                highlightMacros: true
                placeholderText: "输入指令"
                onEditingFinished: {
                    if (root.modelData.execute.kind !== "command")
                        return;
                    root.modelData.execute.value = text;
                    root.changed();
                }
            }
            VariableTextArea {
                id: functionInput
                objectName: "operationExecuteValue"
                visible: executeKind.selected === 2
                x: 8
                y: 4
                width: parent.width - 16
                height: 128
                highlightMacros: true
                onAccepted: {
                    if (root.modelData.execute.kind !== "function")
                        return;
                    root.modelData.execute.value = content;
                    root.changed();
                }
            }
        }
    }
}
