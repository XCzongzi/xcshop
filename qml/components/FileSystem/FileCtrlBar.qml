import QtQuick
import xcshop

Item{
    id:root

    property bool hideBackBtn: false
    property string filePath: ""
    property bool createFloder: false

    signal backbtnClicked()

    function defaultElementContent(){
        if (Global.current_element === "Item") {
            return JSON.stringify({
                "item": "",
                "display": { "selected": 0, "element": "" },
                "trigger": []
            })
        }
        return ""
    }

    TextButton{
        visible:!root.hideBackBtn
        x:2
        y:13
        text:"◂返回上一级 "
        radius: 3
        onClicked: root.backbtnClicked()
    }

    XCFile{
        id:xcfile
    }

    ImageButton {
        x:parent.width - width - 3
        y: 5
        btnSize: 24
        btnRadius: 3
        imageSource: "qrc:/assets/gui/element/Bar/newMenu.png"
        onClicked:{
            root.createFloder = true
            createBar.visible = true
        }
    }
    ImageButton {
        x:parent.width - width*2 - 5
        y: 5
        btnSize: 24
        btnRadius: 3
        imageSource: "qrc:/assets/gui/element/Bar/newFile.png"
        onClicked:{
            root.createFloder = false
            createBar.visible = true
        }
    }

    Rectangle{
        id: createBar
        visible: false
        color: Qt.rgba(Colors.background.r,Colors.background.g,Colors.background.b,1)
        y: 5
        x: 3
        width: parent.width - 6
        height: 55
        radius: 3
        Rectangle{
            y: -root.y
            width: root.width - 3
            height: root.parent.height
            color: Colors.mask
            MouseArea{
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    createBar.visible = false
                    createBar_textField.text = ""
                }
            }
        }
        XCText{
            id: createBar_text
            xcText:root.createFloder ? "请输入目录名" : "请输入元素名"
            onCenter: false
            xcFontSize: 12
            x: 5
            y: 5
        }
        TextButton{
            text:" 确认"
            textSize: 12
            y: 5
            x: parent.width - width - 5
            heightBorderSize: 2
            widthBorderSize: 3
            radius: 3
            onClicked:{
                if(root.createFloder){
                    xcfile.folder(Qt.resolvedUrl(root.filePath) + "/" + createBar_textField.text)
                }else{
                    xcfile.write(Qt.resolvedUrl(root.filePath) + "/" + createBar_textField.text + ".xcse" + Global.current_element,
                                 root.defaultElementContent())
                }
                createBar.visible = false
                createBar_textField.text = ""
            }
        }
        XCTextField{
            id: createBar_textField
            y:createBar_text.y + createBar_text.height + 3
            width: parent.width - 10
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 12
            height: 24
        }

    }
    

}
