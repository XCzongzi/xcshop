pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import Qt5Compat.GraphicalEffects

BaseIOPage {
    id: root
    color: Colors.transparent
    workspace: true

    property int inspectorWidth: 260
    property int minimumInspectorWidth: 200
    property int minimumWorkspaceWidth: 280
    property int layoutBarHeight: 72
    property int minimumLayoutBarHeight: 72
    property int minimumCanvasHeight: 200
    property int pageMargin: 10
    property int panelSpacing: 10
    readonly property int maximumInspectorWidth: Math.max(
                                                     minimumInspectorWidth,
                                                     width - minimumWorkspaceWidth
                                                     - pageMargin * 2
                                                     - panelSpacing)
    readonly property int maximumLayoutBarHeight: Math.max(
                                                       minimumLayoutBarHeight,
                                                       height - pageMargin * 2
                                                       - panelSpacing - minimumCanvasHeight)

    Rectangle {
        id: layoutBar
        x: root.pageMargin
        y: root.pageMargin
        width: Math.max(0, inspector.x - root.panelSpacing - x)
        height: Math.min(root.layoutBarHeight, root.maximumLayoutBarHeight)
        z: 1
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

            onDragStarted: pressHeight = layoutBar.height
            onDragMoved: function(delta) {
                root.layoutBarHeight = Math.max(
                            root.minimumLayoutBarHeight,
                            Math.min(root.maximumLayoutBarHeight,
                                     pressHeight + delta))
            }
        }
    }

    Rectangle {
        id: canvasArea
        x: layoutBar.x
        y: layoutBar.y + layoutBar.height + root.panelSpacing
        width: layoutBar.width
        height: Math.max(0, parent.height - y - root.pageMargin)
        radius: 10
        color: Colors.changeA(Colors.foreground, 0.18)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.07)

        ContainerBox{
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: canvasArea.width
                    height: canvasArea.height
                    radius: canvasArea.radius
                }
            }
        }
        
    }

    Rectangle {
        id: inspector
        x: parent.width - root.pageMargin - width
        y: root.pageMargin
        width: Math.min(root.inspectorWidth, root.maximumInspectorWidth)
        height: Math.max(0, parent.height - root.pageMargin * 2)
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

            onDragStarted: pressWidth = inspector.width
            onDragMoved: function(delta) {
                root.inspectorWidth = Math.max(
                            root.minimumInspectorWidth,
                            Math.min(root.maximumInspectorWidth,
                                     pressWidth - delta))
            }
        }
    }
}
