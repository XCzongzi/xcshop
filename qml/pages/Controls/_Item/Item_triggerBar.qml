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
    function load() {
        triggerKind.selected = modelData.mode.kind === "drop_item" ? 1 : 0;
        dropQuantity.selected = modelData.mode.quantity === "all" ? 1 : 0;
        var filter = modelData.mode.filter || {
            kind: "none"
        };
        filterKind.selected = Math.max(0, ["none", "quantity", "slot"].indexOf(filter.kind));
        quantityMode.selected = Math.max(0, ["all", "less_than_all", "custom"].indexOf(filter.mode));
        executeKind.selected = Math.max(0, ["grant_item", "command", "function"].indexOf(modelData.execute.kind));
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
                filterKind.selected = 0;
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
            ComboBox {
                id: filterKind
                options: ["无筛选", "数量筛选", "栏位筛选"]
                onClicked: {
                    root.modelData.mode.filter = selected === 1 ? {
                        kind: "quantity",
                        mode: "all"
                    } : selected === 2 ? {
                        kind: "slot",
                        slot: "0"
                    } : {
                        kind: "none"
                    };
                    quantityMode.selected = 0;
                    root.changed();
                }
            }
            ComboBox {
                id: quantityMode
                visible: filterKind.selected === 1
                options: ["全部（左键）", "少于全部（右键）", "自定义"]
                onClicked: {
                    root.modelData.mode.filter = {
                        kind: "quantity",
                        mode: ["all", "less_than_all", "custom"][selected]
                    };
                    if (selected === 2)
                        root.modelData.mode.filter.amount = "1";
                    root.changed();
                }
            }
            XCTextField {
                objectName: "triggerAmount"
                visible: filterKind.selected === 1 && quantityMode.selected === 2
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
                visible: filterKind.selected === 2
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
            color: Colors.changeA(Colors.text, 0.08)
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
                text: {
                    root.revision;
                    return root.modelData.execute.value || "";
                }
                onEditingFinished: {
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
                content: {
                    root.revision;
                    return root.modelData.execute.value || "";
                }
                onAccepted: {
                    root.modelData.execute.value = content;
                    root.changed();
                }
            }
        }
    }
}
