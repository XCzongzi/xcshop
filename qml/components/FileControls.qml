import QtQuick
import QtQuick.Controls
import xcshop

PanelSurface {
    id: root
    width: parent.width - x
    height: 30
    readonly property bool canLocateCurrentElement: Global.get_fileName().length > 0
                                                   && Global.parseElementPath(Global.get_filePath()) !== null
    readonly property bool hasBuildResult: Builder.projectPath.length > 0
                                          && Global.normalizeElementPath(Builder.projectPath).toLowerCase()
                                             === Global.normalizeElementPath(Global.project_location).toLowerCase()
    signal locateCurrentElementRequested()
    signal buildDetailsRequested()

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
        id: pathText
        objectName: "currentElementPath"
        anchors.left: parent.left
        anchors.leftMargin: 16
        width: Math.min(implicitWidth, Math.max(0, buildControls.x - x - 12))
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentRelativeFilePath()
        color: pathPointer.containsMouse || activeFocus
               ? Qt.tint(Colors.banned, Colors.changeA(Colors.accentText, 0.35)) : Colors.banned
        font.family: "微软雅黑"
        font.pixelSize: 12
        font.underline: root.canLocateCurrentElement && (pathPointer.containsMouse || activeFocus)
        elide: Text.ElideRight
        activeFocusOnTab: root.canLocateCurrentElement
        Keys.onReturnPressed: if (root.canLocateCurrentElement) root.locateCurrentElementRequested()
        Keys.onEnterPressed: if (root.canLocateCurrentElement) root.locateCurrentElementRequested()
        Keys.onSpacePressed: if (root.canLocateCurrentElement) root.locateCurrentElementRequested()
        Accessible.role: Accessible.Link
        Accessible.name: "定位当前元素：" + text
        Accessible.onPressAction: if (root.canLocateCurrentElement) root.locateCurrentElementRequested()

        MouseArea {
            id: pathPointer
            anchors.fill: parent
            enabled: root.canLocateCurrentElement
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.locateCurrentElementRequested()
        }
        ToolTip.visible: pathPointer.containsMouse
        ToolTip.delay: 500
        ToolTip.text: Global.get_filePath() + "\n单击定位到元素所在目录"
    }

    Row {
        id: buildControls
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        ToolButton {
            id: buildStatus
            objectName: "quickBuildStatus"
            visible: Builder.running || root.hasBuildResult
            height: 26
            width: Math.min(implicitWidth, 180, Math.max(0, root.width - 72))
            enabled: root.hasBuildResult
            text: Builder.running ? (root.hasBuildResult ? (Builder.state === "检查中" ? "检查中…" : "构建中…") : "其他项目构建中…") : Builder.state
            Accessible.name: text + "，查看构建详情"
            onClicked: root.buildDetailsRequested()
            contentItem: Text {
                text: buildStatus.text
                font.family: "微软雅黑"
                font.pixelSize: 11
                color: root.hasBuildResult && (Builder.state === "构建失败" || Builder.state === "检查失败") ? Colors.error : Colors.banned
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 5
                color: buildStatus.down ? Colors.pressed : buildStatus.hovered ? Colors.fired : Colors.transparent
            }
            ToolTip.visible: hovered && enabled
            ToolTip.delay: 500
            ToolTip.text: Builder.summary + "\n点击查看构建详情" + (Builder.running ? "，可在构建框中取消构建" : "")
        }

        ToolButton {
            id: quickBuildButton
            objectName: "quickBuildButton"
            width: 28
            height: 26
            enabled: Global.project_location.length > 0 && !Builder.running
            Accessible.name: "快捷构建"
            onClicked: Global.requestBuild()
            contentItem: Item {
                Canvas {
                    anchors.centerIn: parent
                    width: 12
                    height: 14
                    property color glyphColor: quickBuildButton.enabled ? Colors.accentText : Colors.banned
                    opacity: quickBuildButton.enabled ? 1 : 0.45
                    onGlyphColorChanged: requestPaint()
                    onPaint: {
                        var context = getContext("2d")
                        context.clearRect(0, 0, width, height)
                        context.fillStyle = glyphColor
                        context.beginPath()
                        context.moveTo(2, 1)
                        context.lineTo(11, 7)
                        context.lineTo(2, 13)
                        context.closePath()
                        context.fill()
                    }
                }
            }
            background: Rectangle {
                radius: 5
                color: quickBuildButton.down ? Colors.pressed
                       : quickBuildButton.hovered ? Colors.fired : Colors.transparent
                border.width: quickBuildButton.activeFocus ? 1 : 0
                border.color: Colors.border
            }
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: "构建当前项目"
        }
    }
}
