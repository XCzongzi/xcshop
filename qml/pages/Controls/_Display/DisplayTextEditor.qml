import QtQuick
import xcshop

Item {
    id: root
    property string content: ""
    property string caption: "文本内容"
    readonly property bool resizing: input.resizing
    signal edited(string value)
    height: 30 + input.height
    function setContent(value) { input.setContent(value) }
    XCText {
        xcText: root.caption
        xcFontSize: 12
        textColor: Colors.banned
        boldFont: false
        onCenter: false
    }
    JsonTextEditorButton {
        anchors.right: parent.right
        y: -3
        targetInput: input
        editorTitle: root.caption
    }
    RichTextEditor {
        id: input
        objectName: "displayTextInput"
        y: 30
        width: parent.width
        height: implicitHeight
        compact: true
        content: root.content
        onEdited: function(value) { root.edited(value) }
    }
}
