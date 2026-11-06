import QtQuick
import xcshop


Rectangle {
    id: root
    property bool showControls: true
    required property XCWindow mainWindow
    readonly property real margins: root.mainWindow.margins
    property bool colorFilling: false
    readonly property bool controlsRevealed: !mainWindow.autoHideTitleBarControls || controlHover.hovered

    signal closeClicked()
    signal maximizeClicked()
    signal minimizeClicked()

    x: margins
    y: margins
    width: parent.width - 2*margins
    height: Constants.titleBarHeight

    color: Colors.transparent

    Rectangle{
        anchors.fill: parent
        color: Colors.background_n
        opacity: root.colorFilling
        topLeftRadius: root.mainWindow.frameRadius
        topRightRadius: root.mainWindow.frameRadius
        Behavior on opacity{
            NumberAnimation{
                duration: 250 / Global.animationSpeed
            }
        }
    }


    XCText{
        id: titleText
        objectName: "windowTitle"
        x:8
        xcText: root.mainWindow.titleBarText
        xcFontSize: 16
    }

    MouseArea {
        anchors.fill: parent
        onPressed: {
            root.mainWindow.finishWindowTransition()
            root.mainWindow.startSystemMove()
        }
        // Snapping to a screen edge is handled by the platform's system move.
        onDoubleClicked: root.maximizeClicked()
    }

    Item {
        objectName: "windowControlRevealArea"
        anchors.top: parent.top
        anchors.right: parent.right
        width: btnRow.width + 32
        height: parent.height + 24
        HoverHandler {
            id: controlHover
            enabled: root.showControls && root.mainWindow.autoHideTitleBarControls
        }

        Row {
            id: btnRow
            objectName: "windowControls"

            // 普通窗口按钮留出边距，最大化时贴紧屏幕边缘。
            readonly property real ctrBtnSize: root.mainWindow.titleButtonSize

            anchors.right: parent.right
            anchors.rightMargin: (36 - ctrBtnSize) / 2
            anchors.top: parent.top
            anchors.topMargin: (root.height - height) / 2
            spacing: 0
            visible: root.showControls
            enabled: root.controlsRevealed
            opacity: root.controlsRevealed ? 1 : 0
            transform: Translate {
                y: root.controlsRevealed ? 0 : -8
                Behavior on y { NumberAnimation { duration: 200 / Global.animationSpeed; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 200 / Global.animationSpeed; easing.type: Easing.InOutQuad } }

            ImageButton {
                id: minimizeBtn
                btnSize: btnRow.ctrBtnSize
                btnRadius: 2
                //最小化按钮
                imageSource: "qrc:/assets/gui/titleBar/minimize.png"
                onClicked: root.minimizeClicked()
            }

            ImageButton {
                id: maximizeBtn
                btnSize: btnRow.ctrBtnSize
                btnRadius: 2
                //最大化/恢复按钮图标切换
                imageSource: root.mainWindow.expanded ?
                    "qrc:/assets/gui/titleBar/restore.png" : "qrc:/assets/gui/titleBar/maximize.png"
                onClicked: root.maximizeClicked()
            }

            ImageButton {
                id: closeBtn
                btnSize: btnRow.ctrBtnSize
                btnRadius: 2
                topRightRadius: Math.max(2, root.mainWindow.frameRadius - 2)
                btnfired: "#FF0000"
                btnpressed: "#a00c0c"
                //关闭按钮
                imageSource: "qrc:/assets/gui/titleBar/close.png"
                onClicked: root.closeClicked()
            }
        }
    }
}
