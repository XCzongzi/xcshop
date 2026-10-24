import QtQuick
import xcshop

Item {
    id: root
    property string content: ""
    property string caption: "JSON 内容"
    property bool loading: false
    readonly property bool resizing: input.resizing
    signal edited(string value)
    height: 30 + input.height
    function setContent(value) {
        loading = true;
        input.setContent(value);
        loading = false;
    }
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
    VariableTextField {
        id: input
        objectName: "displayTextInput"
        y: 30
        width: parent.width
        height: 128
        content: root.content
        onContentChanged: if (!root.loading)
            root.edited(content)
    }
}
