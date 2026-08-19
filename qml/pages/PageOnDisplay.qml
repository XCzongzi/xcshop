import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    workspace: true

    ContentBar{
        id: previewBar
        title: "预览"
        width: root.layout? memberBar.x + memberBar.width - 16 : parent.width - 32
        x: 16
        y: 16 - root.height_output
        contentHeight: 300
    }


    maxHeadContentCount: 3
    headContentMinWidth: frameBar.min_width + memberBar.min_width + noticeTextBar.min_width
    content_height: layout? Math.max(
        frameBar.height, Math.max(
            memberBar.height, noticeTextBar.height
        )
    ) + previewBar.height + 48 
    : previewBar.height + frameBar.height + memberBar.height + noticeTextBar.height + 80

    ContentBar {
        id: frameBar
        title: "框架"
        subtitle: "此处定义头部、尾部文本以及各元素间的分隔"
        x: 16
        y: previewBar.y + previewBar.height + 16
        min_width: 400
        contentHeight: frameBar_separatorInput.y + frameBar_separatorInput.height + 16

        XCText {
            id: frameBar_headText
            y: 64
            x: 16
            xcText: "头部文本（JSON）"
            xcFontSize: 16
            onCenter: false
        }
        JsonTextEditorButton {
            targetInput: frameBar_headContent
            editorTitle: "编辑头部文本 JSON"
            x: parent.width - width - 16
            y: frameBar_headText.y - 2
        }
        VariableTextField {
            id: frameBar_headContent
            x: 16
            y: frameBar_headText.y + frameBar_headText.height + 12
            width: parent.width - 32
            height: 128
            placeholderText: "示例：{\"text\":\"花费：\",\"color\":\"green\"}"
        }
        XCText {
            id: frameBar_endText
            y: frameBar_headContent.y + frameBar_headContent.height + 16
            x: 16
            xcText: "尾部文本（JSON）"
            xcFontSize: 16
            onCenter: false
        }
        JsonTextEditorButton {
            targetInput: frameBar_endContent
            editorTitle: "编辑尾部文本 JSON"
            x: parent.width - width - 16
            y: frameBar_endText.y - 2
        }
        VariableTextField {
            id: frameBar_endContent
            x: 16
            y: frameBar_endText.y + frameBar_endText.height + 12
            width: parent.width - 32
            height: 128
            placeholderText: "示例：{\"text\":\"点击购买\",\"color\":\"blue\",\"underlined\": true}"
        }
        XCText {
            id: frameBar_separator
            y: frameBar_endContent.y + frameBar_endContent.height + 16
            x: 16
            xcText: "分隔文本（JSON）"
            xcFontSize: 16
            onCenter: false
        }
        JsonTextEditorButton {
            targetInput: frameBar_separatorInput
            editorTitle: "编辑分隔文本 JSON"
            x: parent.width - width - 16
            y: frameBar_separator.y - 2
        }
        XCTextField{
            id: frameBar_separatorInput
            x: 16
            y: frameBar_separator.y + frameBar_separator.height + 12
            width : parent.width - 32
            placeholderText: "推荐：+ 或 \\n"
        }
    }
    ContentBar {
        id: memberBar
        title: "成员"
        subtitle: "此处定义显示每一代价元素时的格式"
        x: root.layout? frameBar.x + frameBar.width + 16 : 16
        y: root.layout? frameBar.y : frameBar.y + frameBar.height + 16
        min_width: 400
        contentHeight:memberBar_multiPropertyEdit.y + memberBar_multiPropertyEdit.height + 16

        RadioGroup {
            id: memberBar_radioGroup
            x: 16
            y: 45
            text: "提示顺序"
            options: ["元素 + 值", "值 + 元素"]
            onClicked: memberBar_multiPropertyEdit.selected = 0
        }
        MultiPropertyEdit {
            id: memberBar_multiPropertyEdit
            x: 16
            y: memberBar_radioGroup.y + memberBar_radioGroup.height + 14
            options: memberBar_radioGroup.selected === 0 ? ["项头文本", "代价元素", "项中文本", "代价值", "项尾文本"] : ["项头文本", "代价值", "项中文本", "代价元素", "项尾文本"]
        }
    }
    ContentBar{
        id:noticeTextBar
        title: "提示信息"
        subtitle: "购买成功或失败时的提示与音效"
        min_width: 400
        contentHeight: 300
        x: root.layout? memberBar.x + memberBar.width + 16 : 16
        y: root.layout? previewBar.y : memberBar.y + memberBar.height + 16

    }
}
