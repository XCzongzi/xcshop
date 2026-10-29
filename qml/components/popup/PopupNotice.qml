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
    property string cancelText: "取消"
    property string confirmText: "确认"
    property bool confirmEnabled: true
    property int defaultResult: 1

    dialogHeight: Math.max(194, messageArea.y + messageArea.height + root.actionHeight + 44)

    onAboutToOpen: {
        Qt.callLater(function() { root.forceActiveFocus() })
    }

    Keys.onEscapePressed: close(0)
    Keys.onReturnPressed: close(root.confirmEnabled ? root.defaultResult : 0)
    Keys.onEnterPressed: close(root.confirmEnabled ? root.defaultResult : 0)

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
            objectName: "noticeDismissButton"
            visible: root.doubleButton
            text: root.cancelText
            onClicked: root.close(0)
        },
        ActionButton {
            objectName: "noticeConfirmButton"
            primary: true
            enabled: root.confirmEnabled
            text: root.confirmText
            onClicked: root.close(1)
        }
    ]
}
