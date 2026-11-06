pragma ComponentBehavior: Bound
import QtQuick
import xcshop

// Switch content only after it has faded out. A new request replaces the pending
// destination, so quick navigation always lands on the last selected page.
Item {
    id: root
    anchors.fill: parent
    z: 10000
    visible: running
    focus: running
    property bool running: false
    property bool committing: false
    property var currentValue: null
    property var pendingValue: null
    property real contentOpacity: 1
    property real contentOffset: 0
    property real exitOffset: -6
    property real exitDuration: 110
    property real enterDuration: 180
    property real activeExitDuration: 110
    property real activeEnterDuration: 180
    readonly property real tempo: Math.max(0.1, Global.animationSpeed)
    signal commit(var value)
    signal finished()

    function changeTo(value, force = false) {
        if (!running && currentValue === value && !force) return
        pendingValue = value
        if (outgoing.running) return
        incoming.stop()
        activeExitDuration = exitDuration
        activeEnterDuration = enterDuration
        running = true
        outgoing.start()
    }
    function reset(value) {
        outgoing.stop()
        incoming.stop()
        currentValue = value
        pendingValue = value
        contentOpacity = 1
        contentOffset = 0
        running = false
    }
    function reveal(value) {
        reset(value)
        activeEnterDuration = enterDuration
        contentOpacity = 0
        contentOffset = 10
        running = true
        incoming.start()
    }

    ParallelAnimation {
        id: outgoing
        NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: root.activeExitDuration / root.tempo; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "contentOffset"; to: root.exitOffset; duration: root.activeExitDuration / root.tempo; easing.type: Easing.InOutQuad }
        onFinished: {
            root.currentValue = root.pendingValue
            root.committing = true
            root.commit(root.currentValue)
            root.committing = false
            root.contentOffset = 10
            incoming.start()
        }
    }
    ParallelAnimation {
        id: incoming
        NumberAnimation { target: root; property: "contentOpacity"; to: 1; duration: root.activeEnterDuration / root.tempo; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "contentOffset"; to: 0; duration: root.activeEnterDuration / root.tempo; easing.type: Easing.OutCubic }
        onFinished: { root.running = false; root.finished() }
    }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: event => event.accepted = true }
    Keys.onPressed: event => event.accepted = true
    Keys.onReleased: event => event.accepted = true
}
