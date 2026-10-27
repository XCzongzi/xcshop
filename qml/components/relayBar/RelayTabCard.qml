import QtQuick
import xcshop
import "../../../js/ElementRelayState.js" as RelayState

Rectangle {
    id: root

    property var relayBar

    required property var modelData
    readonly property bool selected: relayBar.currentGroupKey === modelData.key
    readonly property bool customGroup: modelData.key.indexOf("custom:") === 0
    readonly property int customGroupIndex: relayBar.customGroupIndex(modelData.key)
    property bool groupDragging: false
    property bool suppressClick: false
    property bool dragAllowed: false
    width: tabLabel.width + 22
    height: 28
    radius: 7
    readonly property bool dropTarget: relayBar.draggedRecord
                                        && relayBar.dragTargetGroupKey === modelData.key
    color: groupDragging ? Colors.changeA(Colors.pressed, 0.86)
                        : dropTarget ? Colors.changeA(Colors.border, 0.32)
                        : (tabMouse.pressed ? Colors.changeA(Colors.pressed, 0.82)
                        : (selected ? Colors.changeA(Colors.border, 0.20)
                    : (tabMouse.containsMouse ? Colors.changeA(Colors.fired, 0.46)
                                                : Colors.changeA(Colors.background, 0.22))))
    border.width: 1
    border.color: dropTarget ? Colors.changeA(Colors.border, 0.92)
                            : (selected ? Colors.changeA(Colors.border, 0.56)
                            : Colors.changeA(Colors.text, 0.08)
                            )
    scale: dropTarget ? 1.12 : (groupDragging ? 0.94 : (tabMouse.pressed ? 0.96 : 1))
    z: dropTarget ? 10 : 0
    transformOrigin: Item.Center

    Behavior on color { ColorAnimation { duration: 110 / Global.animationSpeed } }
    Behavior on border.color { ColorAnimation { duration: 110 / Global.animationSpeed } }
    Behavior on scale { NumberAnimation { duration: 120 / Global.animationSpeed; easing.type: Easing.OutCubic } }

    XCText {
        id: tabLabel
        anchors.centerIn: parent
        xcText: root.modelData.label
        xcFontSize: 11
        boldFont: false
        textColor: root.selected ? Colors.accentText : Colors.text
    }

    Item {
        id: groupDragProxy
        width: 1
        height: 1

        Drag.active: root.groupDragging
        Drag.source: root
        Drag.keys: ["xcshop-relay-group"]
        Drag.hotSpot.x: 0
        Drag.hotSpot.y: 0
    }

    MouseArea {
        id: tabMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        preventStealing: root.customGroup
        drag.target: root.customGroup ? groupDragProxy : null
        drag.threshold: 7

        onPressed: function(mouse) {
            root.dragAllowed = root.customGroup && mouse.button === Qt.LeftButton
            root.suppressClick = false
            groupDragProxy.x = mouse.x
            groupDragProxy.y = mouse.y
        }
        onPositionChanged: {
            if (root.dragAllowed && drag.active && !root.groupDragging) {
                root.groupDragging = root.relayBar.beginGroupDrag(root.modelData.key)
                root.suppressClick = root.groupDragging
            }
        }
        onReleased: {
            var sourceGroupIndex = root.relayBar.draggedGroupIndex
            var targetInsertionIndex = root.relayBar.groupInsertionIndex
            if (root.groupDragging) {
                groupDragProxy.Drag.drop()
                if (targetInsertionIndex >= 0) {
                    Qt.callLater(function() {
                        root.relayBar.finishGroupDrag(sourceGroupIndex,
                                                      targetInsertionIndex)
                    })
                }
            }
            root.relayBar.cancelGroupDrag()
            root.groupDragging = false
            root.dragAllowed = false
            groupDragProxy.x = 0
            groupDragProxy.y = 0
        }
        onCanceled: {
            if (root.groupDragging)
                groupDragProxy.Drag.cancel()
            root.relayBar.cancelGroupDrag()
            root.groupDragging = false
            root.dragAllowed = false
            root.suppressClick = false
            groupDragProxy.x = 0
            groupDragProxy.y = 0
        }
        onClicked: function(mouse) {
            if (root.suppressClick) {
                root.suppressClick = false
                return
            }
            if (mouse.button === Qt.RightButton)
                root.relayBar.showGroupContextMenu(root, mouse.x, mouse.y, root.modelData)
            else
                root.relayBar.selectGroup(root.modelData.key)
        }
    }
    DropArea {
        anchors.fill: parent
        keys: ["xcshop-element", "xcshop-relay-group"]
        onEntered: function(drag) {
            if (root.relayBar.draggedRecord
                    && root.modelData.key !== root.relayBar.currentGroupKey) {
                root.relayBar.setDragTarget(root.modelData.key)
                drag.acceptProposedAction()
            } else if (root.customGroup && root.relayBar.draggedGroupKey.length
                       && root.relayBar.draggedGroupKey !== root.modelData.key) {
                root.relayBar.setGroupInsertion(root.modelData.key,
                                                root.customGroupIndex
                                                + (drag.x >= width / 2 ? 1 : 0))
                drag.acceptProposedAction()
            }
        }
        onPositionChanged: function(drag) {
            if (root.customGroup && root.relayBar.draggedGroupKey.length
                    && root.relayBar.draggedGroupKey !== root.modelData.key)
                root.relayBar.setGroupInsertion(root.modelData.key,
                                                root.customGroupIndex
                                                + (drag.x >= width / 2 ? 1 : 0))
        }
        onExited: {
            root.relayBar.clearDragTarget(root.modelData.key)
            root.relayBar.clearGroupInsertion(root.modelData.key)
        }
        onDropped: function(drop) {
            if (root.relayBar.draggedRecord
                    && root.modelData.key !== root.relayBar.currentGroupKey) {
                var record = RelayState.clone(root.relayBar.draggedRecord)
                var targetKey = root.modelData.key
                drop.acceptProposedAction()
                root.relayBar.clearDragTarget()
                Qt.callLater(function() {
                    root.relayBar.moveRecordToGroup(record, targetKey)
                })
            } else if (root.relayBar.draggedGroupKey.length
                       && root.relayBar.draggedGroupKey !== root.modelData.key) {
                drop.acceptProposedAction()
            }
        }
    }

    Rectangle {
        readonly property bool insertAfter: root.relayBar.groupInsertionIndex
                                            === root.customGroupIndex + 1
        visible: root.relayBar.groupInsertionTargetKey === root.modelData.key
                 && root.relayBar.draggedGroupKey !== root.modelData.key
        z: 20
        x: insertAfter ? root.width - width : 0
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 6
        radius: 2
        color: Colors.border
    }
}
