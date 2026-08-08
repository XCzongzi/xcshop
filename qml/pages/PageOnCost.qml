import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    workspace: true
    content_height: displayInput.height + typeInput.height + 44

    ContentBar {
        id: displayInput
        x: 20
        y: 16 - root.height_output
        width: parent.width - 40
        contentHeight: displayInput_textField.y + displayInput_textField.height + 18

        XCText {
            id: displayInput_propertyText
            y: 18
            x: 20
            xcText: "显示名称"
            xcFontSize: 17
            onCenter: false
        }
        XCText {
            x: 20
            y: 45
            xcText: "该名称会显示在商店界面中。"
            xcFontSize: 12
            onCenter: false
            boldFont: false
            textColor: Colors.banned
        }
        XCTextField {
            id: displayInput_textField
            y: 72
            x: 20
            width: parent.width - 40
            placeholderText: "例如：钻石、经验等级或自定义货币"
        }
    }

    ContentBar {
        id: typeInput
        x: 20
        y: displayInput.y + displayInput.height + 12
        width: parent.width - 40
        contentHeight: typeInput_propertyText.visible ? itemInput_field.y + itemInput_field.height + 18
                                             : typeInput_radioGroup.y + typeInput_radioGroup.height + 24

        XCText { x: 20; y: 18; xcText: "代价类型"; xcFontSize: 17; onCenter: false }
        XCText { x: 20; y: 45; xcText: "选择商店扣除资源的方式。"; xcFontSize: 12; onCenter: false; boldFont: false; textColor: Colors.banned }
        RadioGroup {
            id: typeInput_radioGroup
            y: 72
            text: ""
            options: ["经验等级", "物品数量", "计分板分数", "目标选择器"]
            anchors.horizontalCenter: parent.horizontalCenter
        }
        XCText {
            id: typeInput_propertyText
            visible: typeInput_radioGroup.selected !== 0
            x: 20
            y: typeInput_radioGroup.y + typeInput_radioGroup.height + 12
            xcText: typeInput_radioGroup.selected === 1 ? "物品标识" : typeInput_radioGroup.selected === 2 ? "计分板名称" : "目标选择器（仅筛选，不会进行扣除）"
            xcFontSize: 15
            onCenter: false
        }
        VariableTextField {
            id: itemInput_field
            visible: typeInput_propertyText.visible
            x: 20
            y: typeInput_propertyText.y + typeInput_propertyText.height + 8
            width: parent.width - 40
            height: 128
        }
    }
}
