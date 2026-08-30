import QtQuick

Rectangle {
    id: root
    width: parent.width - x
    height: 30
    color: Colors.foreground

    function currentRelativeFilePath(){
        if(!Global.project_location.length || !Global.get_fileName().length)
            return "未选择文件"

        var projectRoot = Global.normalizeElementPath(Global.project_location)
        var filePath = Global.normalizeElementPath(Global.get_filePath())
        var prefix = projectRoot + "/"
        return filePath.indexOf(prefix) === 0
                ? filePath.substring(prefix.length)
                : filePath
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentRelativeFilePath()
        color: Colors.banned
        font.family: "微软雅黑"
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
