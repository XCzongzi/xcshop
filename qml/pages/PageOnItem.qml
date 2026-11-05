import QtQuick
import xcshop
import "../../js/WorkspaceSchema.js" as Schema

BaseIOPage {
    id: root
    color: "transparent"
    workspace: true
    property bool operationDeleting: false
    property bool operationAdding: false
    readonly property bool operationMoving: operationSwap.running
    function elementReading() {
        if (!Array.isArray(eledata.operations) || eledata.cost !== undefined || eledata.trigger !== undefined)
            throw new Error("此页面只支持操作组格式，请使用新建项目");
        var itemSyntaxError = itemField.isSyntaxError(eledata.item);
        if (eledata.itemSyntaxError !== itemSyntaxError) {
            eledata.itemSyntaxError = itemSyntaxError;
            root.updateDataOut();
        }
        inheritanceEnabled.checked = !!eledata.operationsFrom;
        inheritanceElement.setElement(eledata.operationsFrom || "", false);
        displayMode.selected = eledata.display.mode === "additional" ? 1 : 0;
        displayElement.setElement(eledata.display.element, false);
        for (var i = 0; i < eledata.operations.length; ++i)
            operationRows.add(eledata.operations[i]);
        Qt.callLater(function () {
            displayBar.expand();
            operationsBar.expand();
        });
    }
    function setOperationsFrom(path) {
        var error = Global.operationInheritanceError(path, [Global.get_filePath()]);
        if (error.length) {
            inheritanceElement.setElement(eledata.operationsFrom || "", false);
            SignalBus.sendToMain("Popup.show", {
                component: Constants.popupNotice,
                properties: {title: "无法继承操作组", content: error}
            });
            return;
        }
        eledata.operationsFrom = Global.projectRelativeElementPath(path);
        updateDataOut();
    }
    function addOperation(animate) {
        if (operationDeleting || operationAdding || operationMoving)
            return;
        operationAdding = animate !== false;
        eledata.operations.push(Schema.operation());
        operationRows.add(eledata.operations[eledata.operations.length - 1], operationAdding);
        updateDataOut();
    }
    function removeOperation(index) {
        eledata.operations.splice(index, 1);
        operationRows.removeAt(index);
        updateDataOut();
    }
    function moveOperationUp(index) {
        if (operationDeleting || operationAdding || operationMoving || index <= 0 || index >= operationRows.count)
            return;
        for (var i = 0; i < operationRows.count; ++i) {
            var card = operationCards.itemAt(i);
            if (card.deleting || card.costDeleting || card.costAdding || card.appearing)
                return;
        }
        operationSwap.begin(index, operationCards.itemAt(index - 1).height + cards.spacing,
            operationCards.itemAt(index).height + cards.spacing);
    }
    AnimatedListSwap {
        id: operationSwap
        onFinished: function (row) {
            var operation = root.eledata.operations.splice(row, 1)[0];
            root.eledata.operations.splice(row - 1, 0, operation);
            operationRows.move(row, row - 1, 1);
            root.updateDataOut();
        }
    }
    AnimatedListRemoval {
        id: operationRemoval
        onFinished: function (row) {
            root.removeOperation(row);
            root.operationDeleting = false;
        }
    }
    function itemTextureSource(value) {
        var match = String(value || "").trim().match(/^([a-z0-9_.-]+(?::[a-z0-9_./-]+)?)/i);
        var path = Global.getItemTexturePath(match ? match[1] : "");
        return path.length ? "file:///" + path.replace(/\\/g, "/") : "";
    }
    maxHeadContentCount: 2
    headContentMinWidth: itemBar.min_width + displayBar.min_width
    content_height: operationsBar.y + root.height_output + operationsBar.height + 16
    ContentBar {
        id: itemBar
        x: 16
        y: 16 - root.height_output
        min_width: 400
        title: "物品 ID"
        subtitle: "物品 ID、物品组件与数量"
        contentHeight: itemField.y + itemField.height + 16
        VariableTextField {
            id: itemField
            x: 16
            y: 70
            width: parent.width - 32
            height: 180
            content: root.eledata.item || ""
            syntaxHighlightMode: Global.syntaxVersion
            highlightMacros: true
            onAccepted: {
                root.eledata.item = content;
                root.eledata.itemSyntaxError = syntaxError;
                root.updateDataOut();
            }
        }
        Image {
            x: parent.width - width - 16
            y: 12
            width: 48
            height: 48
            source: root.itemTextureSource(itemField.inputContent)
            fillMode: Image.PreserveAspectFit
            smooth: false
            visible: status === Image.Ready
        }
    }
    ContentBar {
        id: displayBar
        delayExpand: true
        x: root.layout ? itemBar.x + itemBar.width + 16 : 16
        y: root.layout ? itemBar.y : itemBar.y + itemBar.height + 16
        min_width: 440
        title: "商品展示"
        contentHeight: displayMode.selected === 1 ? displayElement.y + displayElement.height + 20 : 104
        RadioGroup {
            id: displayMode
            x: 16
            y: 54
            options: ["仅原物品", "额外添加展示元素"]
            onClicked: {
                root.eledata.display.mode = selected === 1 ? "additional" : "original";
                if (selected === 0) {
                    root.eledata.display.element = "";
                    displayElement.clearElement(false);
                }
                root.updateDataOut();
            }
        }
        ElementSelection {
            id: displayElement
            selectionId: "display"
            x: 16
            y: displayMode.y + displayMode.height + 16
            visible: displayMode.selected === 1
            onElementSelected: function (path) {
                root.eledata.display.element = path;
                root.updateDataOut();
            }
            onSelectionCleared: {
                root.eledata.display.element = "";
                root.updateDataOut();
            }
        }
    }
    ContentBar {
        id: operationsBar
        objectName: "operationsBar"
        delayExpand: true
        x: 16
        y: root.layout ? Math.max(itemBar.y + itemBar.height, displayBar.y + displayBar.height) + 16 : displayBar.y + displayBar.height + 16
        width: root.width - 32
        title: "操作组"
        contentHeight: cards.y + cards.height + 16
        Row {
            id: inheritanceRow
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 10
            spacing: 8
            XCCheckBox {
                id: inheritanceEnabled
                objectName: "operationInheritanceEnabled"
                text: "继承自"
                anchors.verticalCenter: parent.verticalCenter
                onToggled: function (value) {
                    if (!value) {
                        inheritanceElement.clearElement(false);
                        root.eledata.operationsFrom = "";
                        root.updateDataOut();
                    }
                }
            }
            ElementSelectionCompact {
                id: inheritanceElement
                objectName: "operationInheritanceElement"
                selectionId: "item"
                visible: inheritanceEnabled.checked
                width: Math.max(120, Math.min(380, operationsBar.width - inheritanceEnabled.width - 124))
                height: 36
                onElementSelected: function (path) { root.setOperationsFrom(path); }
                onSelectionCleared: {
                    root.eledata.operationsFrom = "";
                    root.updateDataOut();
                }
            }
        }
        Column {
            id: cards
            x: 16
            y: 62
            width: parent.width - 32
            spacing: 12
            height: implicitHeight - operationRemoval.offset
            ObjectListModel {
                id: operationRows
            }
            Repeater {
                id: operationCards
                model: operationRows
                delegate: Item_operationCard {
                    required property string objectKey
                    required animateInsertion
                    objectName: "operationCard" + index
                    width: parent.width
                    z: operationSwap.running && index === operationSwap.index ? 1 : -index
                    operation: operationRows.value(objectKey)
                    listShift: operationRemoval.shiftFor(index) + operationSwap.shiftFor(index)
                    onEdited: root.updateDataOut()
                    onRemovalStarted: root.operationDeleting = true
                    onInsertionFinished: root.operationAdding = false
                    onRemoveRequested: operationRemoval.begin(index, height + cards.spacing)
                    onMoveUpRequested: root.moveOperationUp(index)
                }
            }
            TextButton {
                transform: Translate {
                    y: -operationRemoval.offset
                }
                objectName: "addOperation"
                width: parent.width
                height: 44
                text: "＋ 添加操作"
                radius: 8
                textSize: 14
                textColor: Colors.banned
                buttonColor: Colors.changeA(Colors.background, 0.38)
                onClicked: root.addOperation()
            }
        }
        // 动画期间只拦截输入，不禁用卡片，避免按钮切换成禁用颜色。
        MouseArea {
            objectName: "operationInputGuard"
            x: cards.x
            y: cards.y
            width: cards.width
            height: cards.height
            z: 1000
            visible: root.operationDeleting || root.operationAdding || root.operationMoving
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onVisibleChanged: if (visible)
                forceActiveFocus()
            onWheel: function (event) {
                event.accepted = true;
            }
            Keys.onPressed: function (event) {
                event.accepted = true;
            }
            Keys.onReleased: function (event) {
                event.accepted = true;
            }
        }
    }
}
