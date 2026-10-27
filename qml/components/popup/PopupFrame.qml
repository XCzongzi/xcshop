import QtQuick
import xcshop

// PopupLoader and locally hosted pickers share the same shell and lifecycle.
Item {
    id: root
    anchors.fill: parent
    focus: true
    property string title: ""
    property real dialogWidth: 520
    property real dialogHeight: 330
    property bool closeOnScrim: false
    property var cancelResult: null
    property var result: null
    property bool opened: false
    property bool manageVisibility: false
    readonly property real availableWidth: panel.width - 48
    readonly property real availableHeight: panel.height - 100
    readonly property real actionHeight: footer.height
    readonly property real actionWidth: footer.width
    property alias actions: footer.data
    default property alias body: contentHost.data
    signal aboutToOpen
    signal closed(var result)

    function open() {
        closeAnimation.stop()
        visible = true
        opened = true
        result = null
        scrim.opacity = 0
        panel.opacity = 0
        panel.scale = 0.97
        forceActiveFocus()
        aboutToOpen()
        openAnimation.restart()
    }
    function close(value) {
        if (closeAnimation.running)
            return
        result = value === undefined ? cancelResult : value
        openAnimation.stop()
        closeAnimation.restart()
    }
    Keys.onEscapePressed: close(cancelResult)

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "black"
        opacity: 0
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (root.closeOnScrim)
                root.close(root.cancelResult)
            onWheel: function (event) {
                event.accepted = true
            }
        }
    }
    Rectangle {
        id: panel
        objectName: "popupPanel"
        anchors.centerIn: parent
        width: Math.min(root.dialogWidth, Math.max(0, root.width - 48))
        height: Math.min(root.dialogHeight, Math.max(0, root.height - 48))
        bottomLeftRadius: 15
        bottomRightRadius: 15
        color: Colors.changeA(Colors.background, 0.985)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.12)
        opacity: 0
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: XCShadow {
            shadowColor: "#a8000000"
            shadowBlur: 0.85
            shadowVerticalOffset: 10
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
        Rectangle {
            width: parent.width
            height: 5
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
        Item {
            id: contentHost
            anchors.fill: parent
        }
        Row {
            id: footer
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 8
        }
    }
    ParallelAnimation {
        id: openAnimation
        PropertyAnimation {
            target: scrim
            property: "opacity"
            to: 0.42
            duration: 180 / Global.animationSpeed
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: panel
            property: "opacity"
            to: 1
            duration: 180 / Global.animationSpeed
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: panel
            property: "scale"
            to: 1
            duration: 220 / Global.animationSpeed
            easing.type: Easing.OutBack
        }
    }
    ParallelAnimation {
        id: closeAnimation
        PropertyAnimation {
            target: scrim
            property: "opacity"
            to: 0
            duration: 150 / Global.animationSpeed
            easing.type: Easing.InCubic
        }
        PropertyAnimation {
            target: panel
            property: "opacity"
            to: 0
            duration: 130 / Global.animationSpeed
            easing.type: Easing.InCubic
        }
        PropertyAnimation {
            target: panel
            property: "scale"
            to: 0.97
            duration: 150 / Global.animationSpeed
            easing.type: Easing.InCubic
        }
        onFinished: {
            root.opened = false
            if (root.manageVisibility)
                root.visible = false
            root.closed(root.result)
        }
    }
}
