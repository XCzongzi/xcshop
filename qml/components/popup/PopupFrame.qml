pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import xcshop

// PopupLoader and locally hosted pickers share the same shell and lifecycle.
Item {
    id: root
    anchors.fill: parent
    focus: true
    property string title: ""
    property real dialogWidth: 520
    property real dialogHeight: 330
    property bool useGlobalElementRelay: false
    property real bottomInset: 0
    property bool closeOnScrim: false
    property var cancelResult: null
    property var result: null
    property bool opened: false
    readonly property bool closing: closeAnimation.running
    property bool manageVisibility: false
    property real backdropBlur: 0.15
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

    // Crossfade a softly blurred copy over the page; the dialog stays sharp.
    Loader {
        objectName: "popupBackdropBlur"
        anchors.fill: parent
        active: root.visible && root.opened && root.backdropBlur > 0
                && Global.mainWindow_popupBackdrop !== null && GraphicsInfo.api !== GraphicsInfo.Software
        opacity: scrim.opacity / 0.24
        sourceComponent: Item {
            ShaderEffectSource {
                id: pageCapture
                anchors.fill: parent
                sourceItem: Global.mainWindow_popupBackdrop
                visible: false
                live: true
                sourceRect: {
                    if (!sourceItem) return Qt.rect(0, 0, 0, 0)
                    sourceItem.width; sourceItem.height
                    return root.mapToItem(sourceItem, Qt.rect(0, 0, root.width, root.height))
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: pageCapture
                blurEnabled: true
                blurMax: 32
                blur: root.backdropBlur
                autoPaddingEnabled: false
            }
        }
    }
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
    FrostedSurface {
        id: panel
        objectName: "popupPanel"
        z: 1
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.bottomInset / 2
        width: Math.min(root.dialogWidth, Math.max(0, root.width - 48))
        height: Math.min(root.dialogHeight, Math.max(0, root.height - root.bottomInset - 48))
        radius: 0
        topLeftRadius: 6
        topRightRadius: 6
        bottomLeftRadius: 15
        bottomRightRadius: 15
        border.width: 1
        border.color: Colors.changeA(Colors.outline, 0.12)
        opacity: 0
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
        Item {
            width: parent.width
            height: 5
            clip: true
            Rectangle {
                width: parent.width
                height: Math.max(parent.height, panel.topLeftRadius * 2)
                topLeftRadius: panel.topLeftRadius
                topRightRadius: panel.topRightRadius
                color: Colors.border
            }
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
            color: Colors.changeA(Colors.outline, 0.10)
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
            to: 0.24
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
