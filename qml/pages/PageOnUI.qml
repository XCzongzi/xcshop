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

    LayoutManager {
        id: layoutBar
        x: root.pageMargin
        y: root.pageMargin
        width: Math.max(0, inspector.x - root.panelSpacing - x)
        z: 1
        desiredHeight: root.layoutBarHeight
        minimumHeight: root.minimumLayoutBarHeight
        maximumHeight: root.maximumLayoutBarHeight

        onHeightRequested: function(height) {
            root.layoutBarHeight = height
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

    Inspector {
        id: inspector
        x: parent.width - root.pageMargin - width
        y: root.pageMargin
        height: Math.max(0, parent.height - root.pageMargin * 2)
        desiredWidth: root.inspectorWidth
        minimumWidth: root.minimumInspectorWidth
        maximumWidth: root.maximumInspectorWidth

        onWidthRequested: function(width) {
            root.inspectorWidth = width
        }
    }

}
