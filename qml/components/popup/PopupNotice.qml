pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PopupFrame {
    id: root
    cancelResult: 0

    // Main.qml 在 Loader 创建完成后注入这两个属性。
    title: "提示"
    property string content: ""
    property bool doubleButton: false

    dialogHeight: Math.max(194, messageArea.y + messageArea.height + root.actionHeight + 44)

    onAboutToOpen: {
        Qt.callLater(function() { root.forceActiveFocus() })
    }

    Keys.onEscapePressed: close(0)
    Keys.onReturnPressed: close(1)
    Keys.onEnterPressed: close(1)

    XCScrollView {
        id: messageArea
        x: 28
        y: 94
        width: parent.width - 56
        height: Math.min(contentText.implicitHeight, Math.max(60, root.height - 248))
        contentWidth: availableWidth
        clip: true
        XCText {
            id: contentText
            width: messageArea.availableWidth
            xcText: root.content
            onCenter: false
            xcWrapMode: true
            textFormat: Text.PlainText
            xcFontSize: 14
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.82)
        }
    }
    actions: [
        ActionButton {
            visible: root.doubleButton
            text: "取消"
            onClicked: root.close(0)
        },
        ActionButton {
            primary: true

            text: "确认"
            onClicked: root.close(1)
        }
    ]
}
