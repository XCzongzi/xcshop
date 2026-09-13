import QtQuick
import xcshop

Item {
    id: root

    // true: a horizontal line that resizes vertically; false: the inverse.
    property bool horizontal: false
    property int edgeMargin: 10
    readonly property bool highlighted: resizeArea.containsMouse || resizeArea.pressed
    property real pressScenePosition: 0

    signal dragStarted()
    signal dragMoved(real delta)
    signal dragFinished()
    signal dragCanceled()

    Rectangle {
        x: root.horizontal ? root.edgeMargin : (parent.width - width) / 2
        y: root.horizontal ? (parent.height - height) / 2 : root.edgeMargin
        width: root.horizontal ? Math.max(0, parent.width - root.edgeMargin * 2)
                               : (root.highlighted ? 2 : 1)
        height: root.horizontal ? (root.highlighted ? 2 : 1)
                                : Math.max(0, parent.height - root.edgeMargin * 2)
        radius: Math.min(width, height) / 2
        color: root.highlighted ? Colors.changeA(Colors.border, 0.78)
                                : Colors.changeA(Colors.text, 0.12)

        Behavior on color { ColorAnimation { duration: 120 / Global.animationSpeed } }
        Behavior on width { NumberAnimation { duration: 120 / Global.animationSpeed } }
        Behavior on height { NumberAnimation { duration: 120 / Global.animationSpeed } }
    }

    MouseArea {
        id: resizeArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: root.horizontal ? Qt.SizeVerCursor : Qt.SizeHorCursor

        onPressed: function(mouse) {
            var point = root.mapToItem(null, mouse.x, mouse.y)
            root.pressScenePosition = root.horizontal ? point.y : point.x
            root.dragStarted()
        }

        onPositionChanged: function(mouse) {
            if (!pressed)
                return

            var point = root.mapToItem(null, mouse.x, mouse.y)
            var position = root.horizontal ? point.y : point.x
            root.dragMoved(position - root.pressScenePosition)
        }

        onReleased: root.dragFinished()
        onCanceled: root.dragCanceled()
    }
}
