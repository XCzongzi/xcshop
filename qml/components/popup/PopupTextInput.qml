pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PopupFrame {
    id: root
    dialogWidth: 500
    dialogHeight: 226

    title: "输入内容"
    property string content: ""
    property string value: ""
    property string confirmText: "确认"

    onAboutToOpen: {
        input.text = value
        Qt.callLater(function() {
            input.forceActiveFocus()
            input.selectAll()
        })
    }

    Keys.onEscapePressed: close(null)
    Keys.onReturnPressed: close(input.text)
    Keys.onEnterPressed: close(input.text)

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
        x: 24
        y: 112
        width: parent.width - 48
        height: 36
        onAccepted: root.close(text)
    }
    actions: [
        ActionButton {
            text: "取消"
            onClicked: root.close(null)
        },
        ActionButton {
            primary: true

            text: root.confirmText
            onClicked: root.close(input.text)
        }
    ]
}
