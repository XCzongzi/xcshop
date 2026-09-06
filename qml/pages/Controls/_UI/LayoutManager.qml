import QtQuick
import xcshop

Rectangle {
    id: root

    property int desiredHeight: 72
    property int minimumHeight: 72
    property int maximumHeight: minimumHeight

    signal heightRequested(int height)

    height: Math.min(desiredHeight, maximumHeight)
    radius: 10
    color: Colors.changeA(Colors.foreground, 0.72)
    border.width: 1
    border.color: Colors.changeA(Colors.border, 0.13)

    XCText {
        x: 16
        y: 13
        xcText: "布局管理"
        xcFontSize: 18
        onCenter: false
    }

    ResizeHandle {
        id: layoutResizeHandle
        z: 10
        horizontal: true
        y: parent.height - height / 2
        width: parent.width
        height: 12

        property int pressHeight: 0

        onDragStarted: pressHeight = root.height
        onDragMoved: function(delta) {
            root.heightRequested(Math.max(
                                     root.minimumHeight,
                                     Math.min(root.maximumHeight,
                                              pressHeight + delta)))
        }
    }
}
