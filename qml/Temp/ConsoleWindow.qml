import QtQuick

XCWindow{
    id: root
    width: 800
    height: 500
    title: "Console"
    visible: true
    color:"black"

    signal inputed(var command)

    Rectangle{
        clip: true
        y: root.titleBarHeight
        height: root.height - input.height - root.titleBarHeight
        width: root.width
        color: root.color
        TextEdit{
            id: console
            y: -scrollBar.height_output
            width: root.width
            height: contentHeight + root.height
            font.family: "微软雅黑"
            font.pointSize: 12
            color: "white"
            text: Console.content
        }
        ScrollBar{
            id: scrollBar
            content_height: console.height
        }
        WheelHandler{
            rotationScale: 0.1
            onWheel: function(event) {
                scrollBar.wheelDeltaY = event.angleDelta.y
                scrollBar.wheel()
            }
        }
    }

    Rectangle{
        id: input
        width: root.width
        height: inputText.contentHeight
        y: parent.height - height
        color: "gray"
        TextInput{
            id: inputText
            anchors.fill: parent
            font.family: "微软雅黑"
            font.pointSize: 12
            color: "white"
            text: "_>"
            onAccepted: {
                if(text.slice(0,2) == "_>"){
                    var command = text.replace("_>","")
                    var command_root = command.split(" ")[0]
                    if(command_root == "quit")Qt.quit()
                    if(command_root == "page")root.inputed({c1: "pageSwitch", c2: command.split(" ")[1]})
                }
                Console.output(inputText.text,true)
                inputText.text = "_>"
            }
        }
    }


}