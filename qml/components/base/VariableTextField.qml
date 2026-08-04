import QtQuick
import xcshop

Item{
    id: root
    property string placeholderText
    property string content
    signal accepted()

    Behavior on height {
            NumberAnimation{
                duration: 120
                easing.type: Easing.InOutQuad
            }
        }

    function getContent(){//事实获取编辑框的文本，即使用户还没有提交
        return textField.text
    }

    onContentChanged:{
        textField.text = content
    }
    XCTextField{
        id: textField
        isWrap: true
        width: parent.width
        height: parent.height - 35
        placeholderText: root.placeholderText
        onEditingFinished:{
            root.content = text     //将用户提交的文本同步到content变量
            root.accepted()
        }
    }


    Row{
        y: textField.height + 3
        x: parent.width - width
        ImageButton {
            id: expand_up
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_up.png"
            onClicked: root.height = Math.max(root.height - 128, 128)
        }
        ImageButton {
            id: expand_down
            btnSize: 32
            imgSize: 24
            btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_down.png"
            onClicked: root.height = root.height + 128
        }
    }


}