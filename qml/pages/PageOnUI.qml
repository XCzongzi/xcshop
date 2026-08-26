import QtQuick
import xcshop

BaseIOPage {
    id: root
    color: Colors.transparent
    workspace: true

    Rectangle{
        id: layoutBar
        y: 1
        width: parent.width
        height: 100
        color: Colors.foreground
    }

    Rectangle{
        y: layoutBar.y + layoutBar.height
        x: parent.width - width
        height: parent.height - y
        width: 200
        color: Colors.foreground
    }



}
