import QtQuick
import xcshop

BaseIOPage {
    id: root
    color: Colors.transparent
    workspace: true

    property int inspectorWidth: 260
    property int minimumInspectorWidth: 200
    property int minimumWorkspaceWidth: 280
    property int pageMargin: 10
    property int panelSpacing: 10
    readonly property int maximumInspectorWidth: Math.max(
                                                     minimumInspectorWidth,
                                                     width - minimumWorkspaceWidth
                                                     - pageMargin * 2
                                                     - panelSpacing)

    Rectangle {
        id: layoutBar
        x: root.pageMargin
        y: root.pageMargin
        width: Math.max(0, inspector.x - root.panelSpacing - x)
        height: 72
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

   
        Item {
            id: resizeHandle
            z: 10
            x: -width / 2
            width: 12
            height: parent.height

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                width: resizeArea.containsMouse || resizeArea.pressed ? 2 : 1
                radius: width / 2
                color: resizeArea.containsMouse || resizeArea.pressed
                       ? Colors.changeA(Colors.border, 0.78)
                       : Colors.changeA(Colors.text, 0.12)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on width { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.SizeHorCursor

                property real pressSceneX: 0
                property int pressWidth: 0

                onPressed: function(mouse) {
                    pressSceneX = mapToItem(root, mouse.x, mouse.y).x
                    pressWidth = inspector.width
                }

                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return

                    var currentSceneX = mapToItem(root, mouse.x, mouse.y).x
                    root.inspectorWidth = Math.max(
                                root.minimumInspectorWidth,
                                Math.min(root.maximumInspectorWidth,
                                         pressWidth + pressSceneX - currentSceneX))
                }
            }
        }
    }
}
