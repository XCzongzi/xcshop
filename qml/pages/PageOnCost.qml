import QtQuick
import xcshop

BaseIOPage {
    id: root
    color: Colors.transparent
    workspace: true
    content_height: displayInput.height + typeInput.height + 44
    property int valueEditorSelection: 0

    readonly property var costKinds: [
        "experience_level", "item_count", "scoreboard", "execute_condition"
    ]

    function updateItemSyntaxError(value) {
        root.eledata.itemSyntaxError = root.eledata.type.kind === "item_count"
                && itemInput_field.isSyntaxError(value)
    }

    function syncTypeValue(value) {
        var normalizedValue = value === undefined || value === null ? "" : String(value)
        root.eledata.type.value = normalizedValue
        root.updateItemSyntaxError(normalizedValue)
        itemInput_field.setContent(normalizedValue)
        scoreboardInput.text = normalizedValue
        root.updateDataOut()
    }

    function commitCurrentValueEditor() {
        var value = valueEditorSelection === 2
                    ? scoreboardInput.text : itemInput_field.getContent()
        syncTypeValue(value)
    }

    function elementReading() {
        var type = root.eledata.type
        if (typeof root.eledata.display !== "string" || !type
                || root.costKinds.indexOf(type.kind) < 0
                || typeof type.value !== "string" || typeof type.filter !== "boolean")
            throw new Error("代价元素格式不正确，请使用当前格式的项目")
        root.updateItemSyntaxError(root.eledata.type.value)
        displayInput_textField.text = root.eledata.display
        typeInput_radioGroup.selected = root.costKinds.indexOf(type.kind)
        checkBox.checked = root.eledata.type.filter
        itemInput_field.setContent(root.eledata.type.value)
        scoreboardInput.text = root.eledata.type.value
        valueEditorSelection = typeInput_radioGroup.selected
        root.updateDataOut()

        Qt.callLater(function(){
            typeInput.expand()
        })
    }

    ContentBar {
        id: displayInput
        x: 20
        y: 16 - root.height_output
        width: parent.width - 40
        contentHeight: displayInput_textField.y + displayInput_textField.height + 18

        title: "显示名称"
        XCTextField {
            id: displayInput_textField
            y: 48
            x: 20
            width: parent.width - 40
            placeholderText: "例如：钻石、经验等级或自定义货币"
            onEditingFinished: {
                root.eledata.display = text
                root.updateDataOut()
            }
        }
    }

    ContentBar {
        id: typeInput
        delayExpand: true
        x: 20
        y: displayInput.y + displayInput.height + 12
        width: parent.width - 40
        contentHeight: typeInput_propertyText.visible
                       ? (typeInput_radioGroup.selected === 2
                          ? scoreboardInput.y + scoreboardInput.height + 18
                          : itemInput_field.y + itemInput_field.height + 18)
                                             : checkBox.y + checkBox.height + 24

        title: "代价类型"

        Image {
            objectName: "costItemTexture"
            x: parent.width - width - 16
            y: typeInput_propertyText.y - 12
            width: 40
            height: 40
            source: typeInput_radioGroup.selected === 1
                    ? Global.itemTextureSource(itemInput_field.inputContent) : ""
            fillMode: Image.PreserveAspectFit
            smooth: false
            visible: typeInput_radioGroup.selected === 1 && status === Image.Ready
        }

        RadioGroup {
            id: typeInput_radioGroup
            x: 16
            y: 48
            text: ""
            options: ["经验等级", "物品数量", "计分板分数", "/execute条件"]
            onClicked: {
                root.commitCurrentValueEditor()
                root.valueEditorSelection = selected
                root.eledata.type.kind = root.costKinds[selected]
                root.updateItemSyntaxError(root.eledata.type.value)
                root.updateDataOut()
            }
        }
        XCCheckBox{
            id: checkBox
            x: 16
            y: typeInput_radioGroup.y + typeInput_radioGroup.height + 12
            visible: !(typeInput_radioGroup.selected === 3)
            text: "仅筛选，不进行扣除"
            onToggled: function(checked) {
                root.eledata.type.filter = checked
                root.updateDataOut()
            }
        }

        XCText {
            id: typeInput_propertyText
            visible: typeInput_radioGroup.selected !== 0
            x: 20
            y: typeInput_radioGroup.selected === 3? typeInput_radioGroup.y + typeInput_radioGroup.height + 12 : checkBox.y + checkBox.height + 12
            xcText: typeInput_radioGroup.selected === 1 ? "物品标识" : typeInput_radioGroup.selected === 2 ? "计分板名称" : "条件子命令（仅筛选，不会进行扣除）"
            xcFontSize: 15
            onCenter: false
        }
        VariableTextField {
            id: itemInput_field
            objectName: "costItemInput"
            visible: typeInput_propertyText.visible && typeInput_radioGroup.selected !== 2
            x: 20
            y: typeInput_propertyText.y + typeInput_propertyText.height + 8
            width: parent.width - 40
            height: 128
            content: ""
            placeholderText: typeInput_radioGroup.selected === 3
                             ? "例如：填入\"if/unless items entity @s weapon.mainhand minecraft:diamond_sword\"来检测购买者是/否手持钻石剑"
                             : ""
            syntaxHighlightMode: typeInput_radioGroup.selected === 1 ? Global.syntaxVersion : 0
            onAccepted: {
                root.syncTypeValue(content)
            }
        }

        XCTextField {
            id: scoreboardInput
            visible: typeInput_radioGroup.selected === 2
            x: 20
            y: typeInput_propertyText.y + typeInput_propertyText.height + 8
            width: parent.width - 40
            height: 32
            onEditingFinished: {
                root.syncTypeValue(text)
            }
        }
    }
}
