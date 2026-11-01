pragma ComponentBehavior: Bound
import QtQuick
import xcshop

// Keep the page switch covered until the titlebar fill has settled.
Item {
    id: root
    objectName: "workspaceEntrance"
    visible: busy
    property bool busy: false
    property bool celebrating: false
    property bool closing: false
    property string projectName: ""
    property bool showAboutBrand: false
    property real brandReveal: 0
    property real veil: 0
    property real contentOpacity: 1
    property real reveal: 1
    readonly property real tempo: Math.max(0.1, Global.animationSpeed)
    signal covered()
    signal finished()

    function start(created, name, closingProject = false) {
        if (busy) return
        celebrating = created
        closing = closingProject
        projectName = name || "XCShop"
        brandReveal = 0
        veil = 0
        contentOpacity = 1
        reveal = 1
        busy = true
        timeline.start()
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.background_n
        opacity: root.veil
    }

    Item {
        id: aboutBrand
        objectName: "aboutTransitionBrand"
        anchors.centerIn: parent
        width: Math.min(360, Math.max(0, parent.width - 48))
        height: 160
        visible: root.showAboutBrand
        opacity: root.brandReveal
        scale: 0.94 + 0.06 * root.brandReveal
        transform: Translate { y: 12 * (1 - root.brandReveal) }

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 16

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96; height: 96; radius: 48
                color: "#000000"
                Image {
                    objectName: "aboutTransitionLogo"
                    anchors.fill: parent
                    anchors.margins: 16
                    source: "qrc:/assets/gui/png/logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
            XCText {
                objectName: "aboutTransitionName"
                width: parent.width
                onCenter: false
                horizontalAlignment: Text.AlignHCenter
                xcText: "XCzongzi"
                xcFontSize: 28
                font.letterSpacing: 0.6
            }
        }
    }

    // Block pointer and keyboard input until the final workspace frame is ready.
    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: event => event.accepted = true }
    focus: busy
    Keys.onPressed: event => event.accepted = true
    Keys.onReleased: event => event.accepted = true

    SequentialAnimation {
        id: timeline
        ParallelAnimation {
            NumberAnimation { target: root; property: "veil"; to: 1; duration: 180 / root.tempo; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: 180 / root.tempo; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { root.reveal = 0; root.covered() } }
        // About gets a brief brand reveal; other pages wait for the titlebar fill.
        NumberAnimation { target: root; property: "brandReveal"; to: root.showAboutBrand ? 1 : 0; duration: (root.showAboutBrand ? 240 : 0) / root.tempo; easing.type: Easing.OutCubic }
        PauseAnimation { duration: (root.showAboutBrand ? 320 : 250) / root.tempo }
        NumberAnimation { target: root; property: "brandReveal"; to: 0; duration: (root.showAboutBrand ? 180 : 0) / root.tempo; easing.type: Easing.InCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "veil"; to: 0; duration: 320 / root.tempo; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "contentOpacity"; to: 1; duration: 320 / root.tempo; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "reveal"; to: 1; duration: 400 / root.tempo; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: { root.busy = false; root.finished() } }
    }
}
