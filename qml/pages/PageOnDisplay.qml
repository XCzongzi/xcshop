import QtQuick
import xcshop

BaseIOPage {
    id: root
    color: Colors.transparent
    workspace: true



    function elementReading(){
        memberBar.elementColor = eledata.member.cost.color
        memberBar.elementBold = eledata.member.cost.bold
        memberBar.elementItalic = eledata.member.cost.italic
        memberBar.elementUnderlined = eledata.member.cost.underlined
        memberBar.elementStrikethrough = eledata.member.cost.strikethrough
        memberBar.elementObfuscated = eledata.member.cost.obfuscated
        memberBar.valueColor = eledata.member.value.color
        memberBar.valueBold = eledata.member.value.bold
        memberBar.valueItalic = eledata.member.value.italic
        memberBar.valueUnderlined = eledata.member.value.underlined
        memberBar.valueStrikethrough = eledata.member.value.strikethrough
        memberBar.valueObfuscated = eledata.member.value.obfuscated

        // root.setTextStyle(memberBar_multiPropertyEdit.options[memberBar_multiPropertyEdit.selected] === "代价元素")
    }

    function setTextStyle(editingElement){
        styleEditor.color = editingElement ? memberBar.elementColor : memberBar.valueColor
        styleEditor.bold = editingElement ? memberBar.elementBold : memberBar.valueBold
        styleEditor.italic = editingElement ? memberBar.elementItalic : memberBar.valueItalic
        styleEditor.underlined = editingElement ? memberBar.elementUnderlined : memberBar.valueUnderlined
        styleEditor.strikethrough = editingElement ? memberBar.elementStrikethrough : memberBar.valueStrikethrough
        styleEditor.obfuscated = editingElement ? memberBar.elementObfuscated : memberBar.valueObfuscated
    }


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
        contentHeight: frameBar_multiPropertyEdit.y + frameBar_multiPropertyEdit.height + 16
        property var textContents: ["", "", ""]
        readonly property var textPlaceholders: [
            "示例：{\"text\":\"花费：\",\"color\":\"green\"}",
            "示例：{\"text\":\"点击购买\",\"color\":\"blue\",\"underlined\": true}",
            "推荐：+ 或 \\n"
        ]

        MultiPropertyEdit {
            id: frameBar_multiPropertyEdit
            x: 16
            y: 64
            width: parent.width - 32
            options: ["头部文本", "尾部文本", "分隔文本"]
            onSelectedChanged: frameBar_contentInput.setContent(frameBar.textContents[selected])

            Item {
                id: frameBar_textEditor
                width: parent.width
                height: frameBar_editorCaption.height + 8 + frameBar_contentInput.height

                XCText {
                    id: frameBar_editorCaption
                    xcText: "JSON 内容"
                    xcFontSize: 13
                    onCenter: false
                    boldFont: false
                    textColor: Colors.banned
                }
                JsonTextEditorButton {
                    targetInput: frameBar_contentInput
                    editorTitle: "编辑" + frameBar_multiPropertyEdit.options[frameBar_multiPropertyEdit.selected] + " JSON"
                    anchors.right: parent.right
                    y: -3
                }
                VariableTextField {
                    id: frameBar_contentInput
                    y: frameBar_editorCaption.height + 8
                    width: parent.width
                    height: 128
                    //content: frameTextContents[index]
                    placeholderText: frameBar.textPlaceholders[frameBar_multiPropertyEdit.selected]
                    onContentChanged: frameBar.textContents[frameBar_multiPropertyEdit.selected] = content
                }

            }
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
        property var textContents: ["", "", ""]
        readonly property var textPlaceholders: [
            "输入项头文本，可使用变量",
            "输入项中文本，可使用变量",
            "输入项尾文本，可使用变量"
        ]
        property string elementColor: "white"
        property string valueColor: "white"
        property bool elementBold: false
        property bool valueBold: false
        property bool elementUnderlined: false
        property bool valueUnderlined: false
        property bool elementItalic: false
        property bool valueItalic: false
        property bool elementStrikethrough: false
        property bool valueStrikethrough: false
        property bool elementObfuscated: false
        property bool valueObfuscated: false

        RadioGroup {
            id: memberBar_radioGroup
            x: 16
            y: 80
            text: "提示顺序"
            options: ["元素 + 值", "值 + 元素"]
            onClicked: memberBar_multiPropertyEdit.selected = 0
        }
        MultiPropertyEdit {
            id: memberBar_multiPropertyEdit
            x: 16
            y: memberBar_radioGroup.y + memberBar_radioGroup.height + 14
            width: parent.width - 32
            options: memberBar_radioGroup.selected === 0 ? ["项头文本", "代价元素", "项中文本", "代价值", "项尾文本"] : ["项头文本", "代价值", "项中文本", "代价元素", "项尾文本"]
            activeContentItem: selected % 2 === 0 ? memberBar_textEditor : memberBar_valueEdit
            onSelectedChanged: {
                if (selected % 2 === 0) {
                    memberBar_contentInput.setContent(memberBar.textContents[selected / 2])
                } else {
                    root.setTextStyle(options[selected] === "代价元素")
                }
            }

            Item {
                id: memberBar_textEditor
                width: parent.width
                visible: memberBar_multiPropertyEdit.selected % 2 === 0
                height: memberBar_editorCaption.height + 8 + memberBar_contentInput.height

                XCText {
                    id: memberBar_editorCaption
                    xcText: "JSON 内容"
                    xcFontSize: 13
                    onCenter: false
                    boldFont: false
                    textColor: Colors.banned
                }
                JsonTextEditorButton {
                    targetInput: memberBar_contentInput
                    editorTitle: "编辑" + memberBar_multiPropertyEdit.options[memberBar_multiPropertyEdit.selected] + " JSON"
                    anchors.right: parent.right
                    y: -3
                }
                VariableTextField {
                    id: memberBar_contentInput
                    y: memberBar_editorCaption.height + 8
                    width: parent.width
                    height: 128
                    placeholderText: memberBar.textPlaceholders[memberBar_multiPropertyEdit.selected / 2]
                    onContentChanged: memberBar.textContents[memberBar_multiPropertyEdit.selected / 2] = content
                }
            }
            Item {
                id: memberBar_valueEdit
                width: parent.width
                visible: memberBar_multiPropertyEdit.selected % 2 !== 0
                height: styleEditor.height

                readonly property bool editingElement: memberBar_multiPropertyEdit.options[memberBar_multiPropertyEdit.selected] === "代价元素"

                TextStyleEditor {
                    id: styleEditor
                    onPropertyEdited: {
                        if (memberBar_valueEdit.editingElement) {//更新数据
                            memberBar.elementColor = styleEditor.color
                            memberBar.elementBold = styleEditor.bold
                            memberBar.elementItalic = styleEditor.italic
                            memberBar.elementUnderlined = styleEditor.underlined
                            memberBar.elementStrikethrough = styleEditor.strikethrough
                            memberBar.elementObfuscated = styleEditor.obfuscated
                        } else {
                            memberBar.valueColor = styleEditor.color
                            memberBar.valueBold = styleEditor.bold
                            memberBar.valueItalic = styleEditor.italic
                            memberBar.valueUnderlined = styleEditor.underlined
                            memberBar.valueStrikethrough = styleEditor.strikethrough
                            memberBar.valueObfuscated = styleEditor.obfuscated
                        }
                        //保存数据
                        root.eledata.member.cost.color = memberBar.elementColor
                        root.eledata.member.cost.bold = memberBar.elementBold
                        root.eledata.member.cost.italic = memberBar.elementItalic
                        root.eledata.member.cost.underlined = memberBar.elementUnderlined
                        root.eledata.member.cost.strikethrough = memberBar.elementStrikethrough
                        root.eledata.member.cost.obfuscated = memberBar.elementObfuscated
                        root.eledata.member.value.color = memberBar.valueColor
                        root.eledata.member.value.bold = memberBar.valueBold
                        root.eledata.member.value.italic = memberBar.valueItalic
                        root.eledata.member.value.underlined = memberBar.valueUnderlined
                        root.eledata.member.value.strikethrough = memberBar.valueStrikethrough
                        root.eledata.member.value.obfuscated = memberBar.valueObfuscated

                        root.updateDataOut()
                    }
                }
            }
        }
    }
    ContentBar {
        id: noticeTextBar
        title: "提示信息"
        subtitle: "购买成功或失败时的提示与音效"
        min_width: 400
        contentHeight: noticeMultiPropertyEdit.y + noticeMultiPropertyEdit.height + 16
        x: root.layout? memberBar.x + memberBar.width + 16 : 16
        y: root.layout? previewBar.y : memberBar.y + memberBar.height + 16
        property var textContents: ["", ""]
        property var soundPaths: ["", ""]
        readonly property var textPlaceholders: [
            "示例：{\"text\":\"购买成功\",\"color\":\"green\"}",
            "示例：{\"text\":\"购买失败\",\"color\":\"red\"}"
        ]

        MultiPropertyEdit {
            id: noticeMultiPropertyEdit
            x: 16
            y: 64
            width: parent.width - 32
            options: ["成功信息", "失败信息"]
            activeContentItem: noticeEditor
            onSelectedChanged: {
                noticeTextInput.setContent(noticeTextBar.textContents[selected])
                noticeSoundInput.text = noticeTextBar.soundPaths[selected]
            }

            Item {
                id: noticeEditor
                width: parent.width
                height: noticeSoundInput.y + noticeSoundInput.height

                XCText {
                    id: noticeTextCaption
                    xcText: "提示文本（JSON）"
                    xcFontSize: 16
                    onCenter: false
                }
                JsonTextEditorButton {
                    targetInput: noticeTextInput
                    editorTitle: "编辑" + noticeMultiPropertyEdit.options[noticeMultiPropertyEdit.selected] + "文本 JSON"
                    anchors.right: parent.right
                    y: -2
                }
                VariableTextField {
                    id: noticeTextInput
                    y: noticeTextCaption.height + 12
                    width: parent.width
                    height: 96
                    placeholderText: noticeTextBar.textPlaceholders[noticeMultiPropertyEdit.selected]
                    onContentChanged: noticeTextBar.textContents[noticeMultiPropertyEdit.selected] = content
                    onAccepted: {

                    }
                }
                XCText {
                    id: noticeSoundCaption
                    y: noticeTextInput.y + noticeTextInput.height + 16
                    xcText: "提示音效"
                    xcFontSize: 16
                    onCenter: false
                }
                XCTextField {
                    id: noticeSoundInput
                    y: noticeSoundCaption.y + noticeSoundCaption.height + 12
                    width: parent.width
                    placeholderText: "输入" + noticeMultiPropertyEdit.options[noticeMultiPropertyEdit.selected] + "音效路径"
                    onEditingFinished: noticeTextBar.soundPaths[noticeMultiPropertyEdit.selected] = text
                }
            }
        }
    }
}
