import QtQuick
import xcshop

Item{
    id:root

    property bool hideBackBtn: false
    property string filePath: ""
    property bool createFloder: false

    signal backbtnClicked()
    signal elementPathsDropped(var paths)

    function defaultElementContent(){
        if (Global.current_element === "UI")
            return JSON.stringify({})
        if (Global.current_element === "Item") {
            return JSON.stringify({
                "item": "",
                "display": { "selected": 0, "element": "" },
                "trigger": []
            })
        }
        if (Global.current_element === "Display") {
            return JSON.stringify({"frame":{"head":"","end":"","separator":""},"member":{"order":0,"head":"","middle":"","end":"","cost":{"color":"","bold":false,"underlined":false,"italic":false,"strikethrough":false,"obfuscated":false},"value":{"color":"","bold":false,"underlined":false,"italic":false,"strikethrough":false,"obfuscated":false}},"hint":{"success":["",""],"fail":["",""]}})
        }
        if (Global.current_element === "Cost") {
            return JSON.stringify({
                "display": "",
                "type": { "selected": 0, "value": "", "filter": false }
            })
        }
        return ""
    }

    TextButton{
        id: backButton
        visible:!root.hideBackBtn
        x:2
        y:13
        text:"◂返回上一级 "
        radius: 3
        buttonColor: backDropArea.containsDrag ? Colors.fired : Colors.transparent
        onClicked: root.backbtnClicked()
    }

    DropArea {
        id: backDropArea
        anchors.fill: backButton
        enabled: backButton.visible && SignalBus.draggedElementPaths.length > 0
        keys: ["xcshop-element-paths"]

        onEntered: function(drag) { drag.accepted = true }
        onDropped: function(drop) {
            root.elementPathsDropped(SignalBus.draggedElementPaths.slice())
            drop.acceptProposedAction()
        }
    }

    XCFile{
        id:xcfile
    }

    ImageButton {
        x:parent.width - width - 3
        y: 5
        btnSize: 24
        btnRadius: 3
        imageSource: "qrc:/assets/gui/element/Bar/newMenu_" + Colors.gui_theme + ".png"
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
        imageSource: "qrc:/assets/gui/element/Bar/newFile_" + Colors.gui_theme + ".png"
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
