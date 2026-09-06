import QtQuick
import xcshop

Rectangle {
    id: root

    property int desiredWidth: 260
    property int minimumWidth: 200
    property int maximumWidth: minimumWidth

    signal widthRequested(int width)

    width: Math.min(desiredWidth, maximumWidth)
    radius: 10
    color: Colors.changeA(Colors.foreground, 0.72)
    border.width: 1
    border.color: Colors.changeA(Colors.border, 0.13)

    XCText {
        x: 18
        y: 16
        width: parent.width - 36
        xcText: "检查器"
        xcFontSize: 18
        onCenter: false
    }

    ResizeHandle {
        id: resizeHandle
        z: 10
        horizontal: false
        x: -width / 2
        width: 12
        height: parent.height

        property int pressWidth: 0

        onDragStarted: pressWidth = root.width
        onDragMoved: function(delta) {
            root.widthRequested(Math.max(
                                    root.minimumWidth,
                                    Math.min(root.maximumWidth,
                                             pressWidth - delta)))
        }
    }
}
