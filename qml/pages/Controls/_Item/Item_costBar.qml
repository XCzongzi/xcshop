import QtQuick
import xcshop

ElementConnectionRow {
    id: root
    property bool animateInsertion: false
    property real insertionProgress: animateInsertion ? 0 : 1
    readonly property bool appearing: insertionAnimation.running
    signal insertionFinished

    width: 500
    height: implicitHeight * insertionProgress
    opacity: insertionProgress
    clip: insertionProgress < 1
    selectionType: "cost"
    valueKey: "amount"
    highlightMacros: true

    Component.onCompleted: if (animateInsertion)
        insertionAnimation.start()

    NumberAnimation {
        id: insertionAnimation
        target: root
        property: "insertionProgress"
        from: 0
        to: 1
        duration: 220 / Global.animationSpeed
        easing.type: Easing.OutCubic
        onFinished: root.insertionFinished()
    }
}
