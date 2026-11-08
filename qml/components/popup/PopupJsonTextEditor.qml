pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PopupFrame {
    id: root
    title: "文本内容"
    // Minecraft components are the persisted document format.
    property string jsonText: ""
    property bool singleLine: false
    readonly property string parseError: editor.error
    dialogWidth: 1080
    dialogHeight: 760

    function loadJson(source) { editor.setContent(source) }
    function exportedJson() { return editor.getContent() }
    function apply() { root.close({jsonText: root.exportedJson()}) }
    onAboutToOpen: {
        loadJson(jsonText)
        editor.input.forceActiveFocus()
    }
    RichTextEditor {
        id: editor
        objectName: "popupRichTextEditor"
        singleLine: root.singleLine
        x: 24; y: 82
        width: parent.width - 48
        height: Math.max(0, parent.height - y - 76)
        onAccepted: root.apply()
    }
    XCText {
        x: 24; anchors.bottom: parent.bottom; anchors.bottomMargin: 27
        width: Math.max(0, parent.width - root.actionWidth - 64)
        xcText: root.singleLine ? "仅支持单行 · Ctrl+Enter 应用" : "Enter 换行 · Ctrl+Enter 应用"
        xcFontSize: 11; boldFont: false; textColor: Colors.banned; onCenter: false
    }
    actions: [
        ActionButton { text: "取消"; widthBorderSize: 12; onClicked: root.close(null) },
        ActionButton {
            primary: true
            text: "应用"; widthBorderSize: 18
            onClicked: root.apply()
        }
    ]
}
