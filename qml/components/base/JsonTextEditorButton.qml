import QtQuick
import xcshop

// Opens the visual Minecraft text-component editor for a text input.
// The target may be an XCTextField or a VariableTextField.
TextButton {
    id: root

    property var targetInput: null
    property string editorTitle: "编辑 JSON 文本"

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
        if (!targetInput)
            return ""
        if (targetInput.inputContent !== undefined)
            return targetInput.inputContent
        return targetInput.text || ""
    }

    function applyText(value) {
        if (!targetInput)
            return
        if (typeof targetInput.setContent === "function")
            targetInput.setContent(value)
        else
            targetInput.text = value
        targetInput.forceActiveFocus()
    }

    onClicked: SignalBus.sendToMain("Popup.show", {
        "component": Constants.popupJsonTextEditor,
        "properties": {
            "title": root.editorTitle,
            "jsonText": root.currentText()
        },
        "callback": function(result) {
            if (result && result.jsonText !== undefined)
                root.applyText(result.jsonText)
        }
    })
}
