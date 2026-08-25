import QtQuick

Rectangle {
    id: root
    width: parent.width - x
    height: 30
    color: Colors.foreground

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: Global.current_element
              + (Global.get_fileName().length ? " · " + Global.get_fileName() : "")
        color: Colors.banned
        font.family: "微软雅黑"
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
