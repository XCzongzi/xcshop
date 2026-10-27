import QtQuick
import xcshop

Item {
    id: root
    property string content: ""
    property var input: null
    property bool highlightMacros: false
    property int resizeStep: 128
    property int minimumEditorHeight: 128
    readonly property string inputContent: input ? input.text : ""
    readonly property bool resizing: resizeAnimation.running
    readonly property real inputHeight: Math.max(0, height - 35)
    signal accepted

    function getContent() {
        return inputContent
    }
    function setContent(value) {
        content = value === undefined || value === null ? "" : String(value)
        if (input)
            input.text = content
    }
    function commit() {
        content = inputContent
        accepted()
    }
    onContentChanged: if (input)
        input.text = content
    onInputChanged: if (input)
        input.text = content

    Behavior on height {
        NumberAnimation {
            id: resizeAnimation
            duration: 120 / Global.animationSpeed
            easing.type: Easing.InOutQuad
        }
    }
    Row {
        x: parent.width - width
        y: root.inputHeight + 3
        ImageButton {
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_up.png"
            onClicked: root.height = Math.max(root.height - root.resizeStep, root.minimumEditorHeight)
        }
        ImageButton {
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_down.png"
            onClicked: root.height += root.resizeStep
        }
    }
}
