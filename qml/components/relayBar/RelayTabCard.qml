import QtQuick
import xcshop

Rectangle {
    id: root

    property var relayBar

    required property var modelData
    readonly property bool selected: relayBar.currentGroupKey === modelData.key
    width: tabLabel.width + 22
    height: 28
    radius: 7
    readonly property bool dropTarget: relayBar.draggedRecord
                                        && relayBar.dragTargetGroupKey === modelData.key
    color: dropTarget ? Colors.changeA(Colors.border, 0.32)
                        : (tabMouse.pressed ? Colors.changeA(Colors.pressed, 0.82)
                        : (selected ? Colors.changeA(Colors.border, 0.20)
                    : (tabMouse.containsMouse ? Colors.changeA(Colors.fired, 0.46)
                                                : Colors.changeA(Colors.background, 0.22))))
    border.width: 1
    border.color: dropTarget ? Colors.changeA(Colors.border, 0.92)
                            : (selected ? Colors.changeA(Colors.border, 0.56)
                            : Colors.changeA(Colors.text, 0.08)
                            )
    scale: dropTarget ? 1.12 : (tabMouse.pressed ? 0.96 : 1)
    z: dropTarget ? 10 : 0
    transformOrigin: Item.Center

    Behavior on color { ColorAnimation { duration: 110 } }
    Behavior on border.color { ColorAnimation { duration: 110 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    XCText {
        id: tabLabel
        anchors.centerIn: parent
        xcText: root.modelData.label
        xcFontSize: 11
        boldFont: false
        textColor: root.selected ? Colors.border : Colors.text
    }
    MouseArea {
        id: tabMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.relayBar.selectGroup(root.modelData.key)
    }
    DropArea {
        anchors.fill: parent
        keys: ["xcshop-element"]
        onEntered: function(drag) {
            if (root.relayBar.draggedRecord && root.modelData.key !== relayBar.currentGroupKey) {
                relayBar.setDragTarget(root.modelData.key)
                drag.acceptProposedAction()
            }
        }
        onExited: root.relayBar.clearDragTarget(root.modelData.key)
        onDropped: function(drop) {
            if (root.relayBar.draggedRecord && root.modelData.key !== relayBar.currentGroupKey) {
                var record = RelayState.clone(relayBar.draggedRecord)
                var targetKey = root.modelData.key
                drop.acceptProposedAction()
                relayBar.clearDragTarget()
                Qt.callLater(function() { relayBar.moveRecordToGroup(record, targetKey) })
            }
        }
    }
}
