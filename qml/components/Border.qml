pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    objectName: "windowResizeBorder"
    required property XCWindow mainWindow
    readonly property int resizeMargin: 5

    x: mainWindow.margins
    y: mainWindow.margins
    width: mainWindow.surfaceWidth
    height: mainWindow.surfaceHeight
    visible: mainWindow.visibility === Window.Windowed
    enabled: visible

    Repeater {
        // Corners come last so they take precedence over the edge strips.
        model: [
            { name: "Left", edges: Qt.LeftEdge, cursor: Qt.SizeHorCursor },
            { name: "Right", edges: Qt.RightEdge, cursor: Qt.SizeHorCursor },
            { name: "Top", edges: Qt.TopEdge, cursor: Qt.SizeVerCursor },
            { name: "Bottom", edges: Qt.BottomEdge, cursor: Qt.SizeVerCursor },
            { name: "BottomLeft", edges: Qt.BottomEdge | Qt.LeftEdge, cursor: Qt.SizeBDiagCursor },
            { name: "BottomRight", edges: Qt.BottomEdge | Qt.RightEdge, cursor: Qt.SizeFDiagCursor },
            { name: "TopLeft", edges: Qt.TopEdge | Qt.LeftEdge, cursor: Qt.SizeFDiagCursor },
            { name: "TopRight", edges: Qt.TopEdge | Qt.RightEdge, cursor: Qt.SizeBDiagCursor }
        ]
        delegate: MouseArea {
            required property var modelData
            objectName: "windowResize" + modelData.name
            readonly property bool horizontalEdge: (modelData.edges & (Qt.LeftEdge | Qt.RightEdge)) !== 0
            readonly property bool verticalEdge: (modelData.edges & (Qt.TopEdge | Qt.BottomEdge)) !== 0
            width: horizontalEdge ? root.resizeMargin : root.width
            height: verticalEdge ? root.resizeMargin : root.height
            x: (modelData.edges & Qt.RightEdge) ? root.width - width : 0
            y: (modelData.edges & Qt.BottomEdge) ? root.height - height : 0
            acceptedButtons: Qt.LeftButton
            cursorShape: modelData.cursor
            onPressed: root.mainWindow.startSystemResize(modelData.edges)
        }
    }
}
