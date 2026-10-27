import QtQuick
import QtQuick.Window
import xcshop

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool opened: false
    property bool operationSelected: false
    property bool operationMode: false
    property bool draggable: false
    property var dragPaths: []
    property bool acceptsElementDrop: false
    property bool dropHovered: false
    property bool dragAllowed: false
    readonly property bool highlighted: operationMode ? operationSelected : opened

    signal pressed(var mouse)
    signal clicked(var mouse)
    signal contextMenuRequested(var mouse)
    signal pathsDropped(var paths)

    radius: 3
    color: dropHovered ? Colors.changeA(Colors.border, 0.34)
                       : operationMode && operationSelected
                         ? Colors.changeA(Colors.border, 0.28)
                       : !operationMode && opened ? Colors.selectedRow
                                  : pointer.containsMouse ? Colors.fired : Colors.transparent
    border.width: activeFocus || dropHovered ? 1 : 0
    border.color: dropHovered ? Colors.border : Colors.changeA(Colors.border, 0.82)

    Behavior on color { ColorAnimation { duration: 120 / Global.animationSpeed } }

    Rectangle {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 6
        radius: 2
        visible: root.opened
        color: Colors.border
        opacity: root.operationMode ? 0.82 : 1

        Behavior on opacity { NumberAnimation { duration: 120 / Global.animationSpeed } }
    }

    ThemedIcon {
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.highlighted || pointer.containsMouse ? 22 : 18
        height: width
        iconSource: "qrc:/assets/gui/element/" + root.icon + ".png"
        sourceSize.width: width
        sourceSize.height: height

        Behavior on width { NumberAnimation { duration: 140 / Global.animationSpeed; easing.type: Easing.OutCubic } }
    }

    XCText {
        x: 32
        width: parent.width - 36
        anchors.verticalCenter: parent.verticalCenter
        xcText: root.text
        xcFontSize: 12
        onCenter: false
        elide: Text.ElideRight
    }

    Item {
        id: dragProxy
        parent: root.Window.window ? root.Window.window.contentItem : root
        width: 26
        height: 26
        z: 10000

        Drag.active: pointer.drag.active
        Drag.source: root
        Drag.keys: ["xcshop-element-paths"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.imageSource: Colors.whiteUiIconSource("qrc:/assets/gui/element/" + root.icon + ".png")

        ThemedIcon {
            visible: dragProxy.Drag.active
            anchors.fill: parent
            iconSource: dragProxy.Drag.imageSource
            sourceSize.width: width
            sourceSize.height: height
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        drag.target: root.dragAllowed ? dragProxy : null
        drag.threshold: 6

        onPressed: function(mouse) {
            root.dragAllowed = root.draggable && mouse.button === Qt.LeftButton
            root.forceActiveFocus()
            root.pressed(mouse)
            if (root.dragAllowed) {
                SignalBus.draggedElementPaths = root.dragPaths.slice()
                var scenePosition = root.mapToItem(dragProxy.parent, mouse.x, mouse.y)
                dragProxy.x = scenePosition.x - dragProxy.width / 2
                dragProxy.y = scenePosition.y - dragProxy.height / 2
            }
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton)
                root.contextMenuRequested(mouse)
            else
                root.clicked(mouse)
        }
        onReleased: {
            if (dragProxy.Drag.active)
                dragProxy.Drag.drop()
            root.dragAllowed = false
            SignalBus.draggedElementPaths = []
            dragProxy.x = 0
            dragProxy.y = 0
        }
        onCanceled: {
            root.dragAllowed = false
            SignalBus.draggedElementPaths = []
            dragProxy.Drag.cancel()
            dragProxy.x = 0
            dragProxy.y = 0
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: root.acceptsElementDrop
        keys: ["xcshop-element-paths"]

        onEntered: function(drag) {
            root.dropHovered = true
            drag.accepted = true
        }
        onExited: root.dropHovered = false
        onDropped: function(drop) {
            root.dropHovered = false
            if (SignalBus.draggedElementPaths.length)
                root.pathsDropped(SignalBus.draggedElementPaths.slice())
            drop.acceptProposedAction()
        }
    }
}
