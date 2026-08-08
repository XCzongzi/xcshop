import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    workspace: true
    content_height: editBar.height + 32

    ContentBar {
        id: editBar
        x: 20
        y: 16 - root.height_output
        width: parent.width - 40
        contentHeight: editBar_middle.y + editBar_middle.height + 12
        title: "代价标记"

        XCText{
            id: separatorInput
            text:"分隔符："
            onCenter: false
            x: 16
        }
        ContentBar {
            id: editBar_head
            x: 16
            y: separatorInput.y + separatorInput.height + 16
            width: parent.width - 40
            contentHeight: editBar_head_content.y + editBar_head_content.height + 18
            color: Colors.changeA(Colors.background, 0.34)

            XCText { id: editBar_head_text; y: 16; x: 18; xcText: "头部文本（JSON）"; xcFontSize: 16; onCenter: false }
            VariableTextField {
                id: editBar_head_content
                x: 18
                y: editBar_head_text.y + editBar_head_text.height + 12
                width: parent.width - 36
                height: 128
                placeholderText: "示例：{\"text\":\"花费：\",\"color\":\"green\"}"
            }
        }
        ContentBar {
            id: editBar_middle
            x: 16
            y: editBar_head.y + editBar_head.height + 12
            width: parent.width - 40
            contentHeight:editBar_middle_content.y + editBar_middle_content.height + 16
            color: Colors.changeA(Colors.background, 0.34)

            XCText { x: 18; y: 16; xcText: "文本结构"; xcFontSize: 16; onCenter: false }
            RadioGroup {
                id: editBar_middle_radioGroup
                x: 16
                y: 45
                text: ""
                options: ["元素 + 值", "值 + 元素"]
                onClicked: editBar_middle_multiPropertyEdit.selected = 0
            }
            MultiPropertyEdit {
                id: editBar_middle_multiPropertyEdit
                x: 16
                y: editBar_middle_radioGroup.y + editBar_middle_radioGroup.height + 14
                options: editBar_middle_radioGroup.selected === 0 ? ["项头文本", "代价元素", "项中文本", "代价值", "项尾文本"] : ["项头文本", "代价值", "项中文本", "代价元素", "项尾文本"]
            }
            ContentBar {
                id: editBar_middle_content
                x: 16
                y: editBar_middle_multiPropertyEdit.y + editBar_middle_multiPropertyEdit.height + 8
                color: Colors.changeA(Colors.background, 0.28)
                width: parent.width - 36
                contentHeight: 128
            }
        }

        ContentBar{

            title: "购买提示"
        }
    }
}
