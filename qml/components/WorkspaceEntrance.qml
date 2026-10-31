pragma ComponentBehavior: Bound
import QtQuick
import xcshop

// The opaque midpoint lets the live workspace assemble without a layout flash.
Item {
    id: root
    objectName: "workspaceEntrance"
    visible: busy
    property bool busy: false
    property bool celebrating: false
    property bool closing: false
    property string projectName: ""
    property real veil: 0
    property real textReveal: 0
    property real lineProgress: 0
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
        veil = 0
        textReveal = 0
        lineProgress = 0
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
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -Math.min(48, root.width * 0.05)
        anchors.verticalCenterOffset: -12
        width: Math.min(460, Math.max(0, parent.width - 96))
        height: 142
        opacity: root.textReveal
        transform: Translate { y: 10 * (1 - root.textReveal) }

        XCText {
            y: 0; width: parent.width
            onCenter: false
            xcText: root.closing ? "项目已关闭" : root.celebrating ? "项目已创建" : "继续你的创作"
            xcFontSize: 12; boldFont: false
            font.letterSpacing: 2
            textColor: Colors.accentText
        }
        XCText {
            y: 30; width: parent.width
            onCenter: false
            xcText: root.projectName
            xcFontSize: 32
        }
        XCText {
            y: 85; width: parent.width
            onCenter: false
            xcText: root.closing ? "返回开始界面" : root.celebrating ? "开始你的创作" : "正在进入工作区"
            xcFontSize: 13; boldFont: false
            textColor: Colors.banned
        }
        Rectangle {
            y: 132
            width: 48 + 64 * root.lineProgress
            height: 2; radius: 1
            color: Colors.border
            opacity: 0.7
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
            NumberAnimation { target: root; property: "veil"; to: 1; duration: (root.celebrating ? 280 : 180) / root.tempo; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: 220 / root.tempo; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { root.reveal = 0; root.covered() } }
        NumberAnimation { target: root; property: "textReveal"; to: 1; duration: (root.celebrating ? 420 : 160) / root.tempo; easing.type: Easing.OutCubic }
        PauseAnimation { duration: (root.celebrating ? 650 : 90) / root.tempo }
        ParallelAnimation {
            NumberAnimation { target: root; property: "lineProgress"; to: 1; duration: 620 / root.tempo; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "textReveal"; to: 0; duration: 320 / root.tempo; easing.type: Easing.InCubic }
            SequentialAnimation {
                PauseAnimation { duration: 140 / root.tempo }
                ParallelAnimation {
                    NumberAnimation { target: root; property: "veil"; to: 0; duration: 480 / root.tempo; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: root; property: "contentOpacity"; to: 1; duration: 480 / root.tempo; easing.type: Easing.OutCubic }
                    NumberAnimation { target: root; property: "reveal"; to: 1; duration: 600 / root.tempo; easing.type: Easing.OutCubic }
                }
            }
        }
        ScriptAction { script: { root.busy = false; root.finished() } }
    }
}
