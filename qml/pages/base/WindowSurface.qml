pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import Qt5Compat.GraphicalEffects

Rectangle{
    id: root
    property XCWindow mainWindow
    property bool ignoreTitleBar: false
    x: mainWindow.margins
    y: ignoreTitleBar? mainWindow.margins : mainWindow.margins + Constants.titleBarHeight
    width: mainWindow.surfaceWidth
    height: ignoreTitleBar? mainWindow.surfaceHeight : mainWindow.surfaceHeight - Constants.titleBarHeight
    color: Colors.transparent

    layer.enabled: !mainWindow.expanded
    layer.effect: OpacityMask{
        maskSource: Rectangle{
            width: root.mainWindow.surfaceWidth
            height: root.mainWindow.surfaceHeight
            bottomLeftRadius: Constants.window_radius
            bottomRightRadius: Constants.window_radius
            topLeftRadius: root.ignoreTitleBar? Constants.window_radius : 0
            topRightRadius: root.ignoreTitleBar? Constants.window_radius : 0
        }
    }

}
