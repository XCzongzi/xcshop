pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    anchors.fill: parent
    focus: true

    property string title: "输入内容"
    property string content: ""
    property string value: ""
    property string confirmText: "确认"
    property var result: null

    signal closed(var result)

    function open() {
        scrim.opacity = 0
        dialog.opacity = 0
        dialog.scale = 0.96
        input.text = value
        openAnimation.restart()
        Qt.callLater(function() {
            input.forceActiveFocus()
            input.selectAll()
        })
    }

    function close(closeResult) {
        if (closeAnimation.running)
            return
        result = closeResult === undefined ? null : closeResult
        closeAnimation.restart()
    }

    Keys.onEscapePressed: close(null)
    Keys.onReturnPressed: close(input.text)
    Keys.onEnterPressed: close(input.text)

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "#000000"
        opacity: 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Rectangle {
        id: dialog
        width: Math.min(500, Math.max(330, root.width - 48))
        height: 226
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

        XCText {
            x: 24
            y: 25
            width: parent.width - 48
            xcText: root.title
            onCenter: false
            xcFontSize: 21
        }

        Rectangle {
            x: 24
            y: 65
            width: parent.width - 48
            height: 1
            color: Colors.changeA(Colors.text, 0.10)
        }

        XCText {
            x: 28
            y: 82
            width: parent.width - 56
            xcText: root.content
            onCenter: false
            xcFontSize: 13
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.78)
        }

        XCTextField {
            id: input
            x: 24
            y: 112
            width: parent.width - 48
            height: 36
            onAccepted: root.close(text)
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 8

            TextButton {
                text: "取消"
                height: 34
                radius: 7
                textSize: 13
                widthBorderSize: 12
                buttonColor: Colors.changeA(Colors.pressed, 0.82)
                onClicked: root.close(null)
            }

            TextButton {
                text: root.confirmText
                height: 34
                radius: 7
                textSize: 13
                widthBorderSize: 13
                buttonColor: Colors.changeA(Colors.border, 0.72)
                firedColor: Colors.changeA(Colors.border, 0.88)
                pressedColor: Colors.border
                textColor: "#1b1b1b"
                onClicked: root.close(input.text)
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
