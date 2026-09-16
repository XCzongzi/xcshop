import QtQuick
import xcshop

Item{
    id: root

    property string content
    property bool highlightMacros: false

    signal accepted()

    function getContent(){
        return textArea.text
    }

    onContentChanged:{
        textArea.text = content
    }

    XCTextArea{
        id: textArea
        highlightMacros: root.highlightMacros
        width: parent.width
        height: parent.height - 35
        Behavior on height {
            NumberAnimation{
                duration: 120 / Global.animationSpeed
                easing.type: Easing.InOutQuad
            }
        }
        onEditingFinished:{
            root.content = text
            root.accepted()
        }
    }


    Row{
        y: textArea.height + 3
        x: parent.width - width
        ImageButton {
            id: expand_up
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            //最小化按钮
            imageSource: "qrc:/assets/gui/controls/expand_up.png"
            onClicked: root.height = Math.max(root.height - 128, 128)
        }
        ImageButton {
            id: expand_down
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            //最小化按钮
            imageSource: "qrc:/assets/gui/controls/expand_down.png"
            onClicked: root.height = root.height + 128
        }
    }


}
