pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    anchors.fill: parent

    // Main.qml 在 Loader 创建完成后注入这两个属性。
    property string title: "提示"
    property string content: ""
    property bool doubleButton: false
    property bool closeOnScrim: false
    property int result: 0

    signal closed(int result)

    readonly property int dialogWidth: Math.min(520, Math.max(330, width - 48))
    readonly property int dialogHeight: Math.max(194, contentText.y + contentText.height + actionRow.height + 44)

    function open() {
        scrim.opacity = 0
        dialog.opacity = 0
        dialog.scale = 0.96
        openAnimation.restart()
    }

    function close(closeResult) {
        if (closeAnimation.running)
            return
        result = closeResult === undefined ? 0 : closeResult
        closeAnimation.restart()
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "#000000"
        opacity: 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (root.closeOnScrim)
                    root.close(0)
            }
        }
    }

    Rectangle {
        id: dialog
        width: root.dialogWidth
        height: root.dialogHeight
        anchors.centerIn: parent
        bottomLeftRadius: 15
        bottomRightRadius: 15
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.985)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.12)
        transformOrigin: Item.Center
        opacity: 0

        layer.enabled: true
        layer.effect: XCShadow {
            shadowColor: "#a8000000"
            shadowBlur: 0.85
            shadowVerticalOffset: 10
            shadowHorizontalOffset: 0
        }

        Rectangle {
            width: parent.width
            height: 5
            radius: 15
            color: Colors.border
        }

        Rectangle {
            x: 24
            y: 25
            width: 34
            height: 34
            radius: 10
            color: Colors.changeA(Colors.border, 0.20)

            XCText {
                anchors.centerIn: parent
                xcText: "!"
                xcFontSize: 18
                textColor: Colors.border
            }
        }

        XCText {
            x: 70
            y: 26
            width: parent.width - x - 24
            xcText: root.title
            onCenter: false
            xcFontSize: 21
            textColor: Colors.text
        }

        Rectangle {
            x: 24
            y: 76
            width: parent.width - 48
            height: 1
            color: Colors.changeA(Colors.text, 0.10)
        }

        XCText {
            id: contentText
            x: 28
            y: 94
            width: parent.width - 56
            xcText: root.content
            onCenter: false
            xcWrapMode: true
            xcFontSize: 14
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.82)
        }

        Row {
            id: actionRow
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 8

            TextButton {
                visible: root.doubleButton
                text: "取消"
                height: 34
                radius: 7
                textSize: 13
                widthBorderSize: 12
                buttonColor: Colors.changeA(Colors.pressed, 0.82)
                onClicked: root.close(0)
            }

            TextButton {
                text: "确认"
                height: 34
                radius: 7
                textSize: 13
                widthBorderSize: 13
                buttonColor: Colors.changeA(Colors.border, 0.72)
                firedColor: Colors.changeA(Colors.border, 0.88)
                pressedColor: Colors.border
                textColor: "#1b1b1b"
                onClicked: root.close(1)
            }
        }
    }

    ParallelAnimation {
        id: openAnimation
        PropertyAnimation { target: scrim; property: "opacity"; to: 0.42; duration: 180; easing.type: Easing.OutCubic }
        PropertyAnimation { target: dialog; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        PropertyAnimation { target: dialog; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: closeAnimation
        PropertyAnimation { target: scrim; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
        PropertyAnimation { target: dialog; property: "opacity"; to: 0; duration: 130; easing.type: Easing.InCubic }
        PropertyAnimation { target: dialog; property: "scale"; to: 0.97; duration: 150; easing.type: Easing.InCubic }
        onFinished: root.closed(root.result)
    }
}
