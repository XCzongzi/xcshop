import QtQuick
import xcshop

// Opens the full editor for a RichTextEditor and commits its applied result.
TextButton {
    id: root

    required property RichTextEditor targetInput
    property string editorTitle: "文本内容"
    property bool singleLine: targetInput.singleLine

    text: "彩字编辑"
    height: 26
    radius: 6
    textSize: 12
    boldFont: false
    widthBorderSize: 8
    buttonColor: Colors.changeA(Colors.border, 0.20)
    firedColor: Colors.changeA(Colors.border, 0.36)
    pressedColor: Colors.changeA(Colors.border, 0.52)
    textColor: Colors.text

    function currentText() {
        return targetInput.getContent()
    }

    function applyText(value) {
        targetInput.setContent(value)
        targetInput.commit()
        targetInput.input.forceActiveFocus()
    }

    onClicked: SignalBus.sendToMain("Popup.show", {
        "component": Constants.popupJsonTextEditor,
        "properties": {
            "title": root.editorTitle,
            "jsonText": root.currentText(),
            "singleLine": root.singleLine
        },
        "callback": function(result) {
            if (result && result.jsonText !== undefined)
                root.applyText(result.jsonText)
        }
    })
}
