pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PopupFrame {
    id: root
    dialogWidth: 500
    dialogHeight: root.hintText.length || root.validateValue ? 280 : 226

    title: "输入内容"
    property string content: ""
    property string value: ""
    property string confirmText: "确认"
    property string placeholderText: ""
    property string hintText: ""
    // Validators and submitters return an empty string on success. Keeping the
    // dialog open on failure lets the user correct a name without retyping it.
    property var validateValue: null
    property var submitValue: null
    property string submissionError: ""
    property bool attemptedSubmission: false
    property bool submitted: false
    readonly property string validationError: validateValue ? validateValue(input.text) : ""
    readonly property string errorText: submissionError || validationError

    function submit() {
        if (submitted || closing || input.inputMethodComposing)
            return
        attemptedSubmission = true
        if (validationError.length)
            return
        submissionError = submitValue ? submitValue(input.text) : ""
        if (!submissionError.length) {
            submitted = true
            close(input.text)
        } else
            input.forceActiveFocus()
    }

    onAboutToOpen: {
        input.text = value
        submissionError = ""
        attemptedSubmission = false
        submitted = false
        Qt.callLater(function() {
            input.forceActiveFocus()
            input.selectAll()
        })
    }

    Keys.onEscapePressed: close(null)
    Keys.onReturnPressed: submit()
    Keys.onEnterPressed: submit()

    XCText {
        x: 28
        y: 82
        width: parent.width - 56
        xcText: root.content
        onCenter: false
        xcFontSize: 13
        boldFont: false
        textColor: Colors.changeA(Colors.text, 0.78)
    }

    XCTextField {
        id: input
        objectName: "popupTextInputField"
        x: 24
        y: 112
        width: parent.width - 48
        height: 36
        placeholderText: root.placeholderText
        onTextChanged: root.submissionError = ""
        onAccepted: root.submit()
    }
    Text {
        x: 28
        y: 158
        width: parent.width - 56
        visible: root.hintText.length > 0
        text: root.hintText
        color: Colors.banned
        font.family: "微软雅黑"
        font.pixelSize: 12
        elide: Text.ElideMiddle
    }
    Text {
        objectName: "popupTextInputError"
        x: 28
        y: 180
        width: parent.width - 56
        visible: root.errorText.length > 0 && (input.text.length > 0 || root.attemptedSubmission)
        text: root.errorText
        color: Colors.error
        font.family: "微软雅黑"
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
    actions: [
        ActionButton {
            text: "取消"
            activeFocusOnTab: true
            KeyNavigation.tab: confirmButton
            Keys.onReturnPressed: root.close(null)
            Keys.onEnterPressed: root.close(null)
            Keys.onSpacePressed: root.close(null)
            border.width: activeFocus ? 1 : 0
            border.color: Colors.accentText
            onClicked: root.close(null)
        },
        ActionButton {
            id: confirmButton
            objectName: "popupTextInputConfirm"
            primary: true
            enabled: !root.validationError.length
            activeFocusOnTab: true
            KeyNavigation.tab: input
            Keys.onReturnPressed: root.submit()
            Keys.onEnterPressed: root.submit()
            Keys.onSpacePressed: root.submit()
            border.width: activeFocus ? 1 : 0
            border.color: Colors.accentText
            text: root.confirmText
            onClicked: root.submit()
        }
    ]
}
