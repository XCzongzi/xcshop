import xcshop
import QtQuick


ContentBar{
    id: root
    expanded: true
    contentHeight: 32
    width: parent.width - x - 8
    y: 39
    color: Colors.background
    TextButton{
        id: deleteFile
        x: 8
        width: 18
        height: width
        anchors.verticalCenter: parent.verticalCenter
        text: "<"
        textSize: 20
        radius: 3
    }
    TextButton{
        id: cloneFile
        x: 8 + deleteFile.width
        width: 18
        height: width
        anchors.verticalCenter: parent.verticalCenter
        text: ">"
        textSize: 20
        radius: 3
    }
}