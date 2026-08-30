import QtQuick
import xcshop
import "../../../js/ElementRelayState.js" as RelayState

Item {
    id: root
    property var relayBar

    required property string path
    required property string name
    required property string elementType
    required property string relativePath
    required property int sourceIndex

    // Show the item saved in every Item element whenever the corresponding
    // mapped texture has been generated locally.
    readonly property bool showStoredItemTexture: elementType === "Item"
    readonly property string defaultIconSource: "qrc:/assets/gui/element/" + elementType + ".png"
    readonly property string iconSource: storedItemIconSource()

    property var recordData: ({
        "path": path,
        "name": name,
        "type": elementType,
        "relativePath": relativePath
    })

    XCFile { id: elementFile }

    function itemIdFromValue(value) {
        var text = value === undefined || value === null ? "" : String(value).trim()
        var match = text.match(/^([a-z0-9_.-]+(?::[a-z0-9_./-]+)?)/i)
        return match ? match[1] : ""
    }

    function storedItemIconSource() {
        if (!showStoredItemTexture)
            return defaultIconSource

        var itemData
        try {
            itemData = JSON.parse(elementFile.read(path))
        } catch (error) {
            return defaultIconSource
        }

        var texturePath = Global.getItemTexturePath(itemIdFromValue(itemData ? itemData.item : ""))
        if (!texturePath.length || !elementFile.exists(texturePath))
            return defaultIconSource

        return "file:///" + texturePath.replace(/\\/g, "/")
    }


    Rectangle {
        id: card
        property bool dragging: false
        property bool suppressClick: false
        readonly property bool reorderTarget: root.relayBar.draggedRecord
                                            && root.relayBar.dragTargetGroupKey === root.relayBar.currentGroupKey
                                            && root.relayBar.dragTargetSourceIndex === root.sourceIndex
                                            && root.relayBar.draggedSourceIndex !== root.sourceIndex
        x: 4
        y: 4
        width: root.width - 8
        height: root.height - 8
        radius: 9
        color: card.dragging ? Colors.changeA(Colors.pressed, 0.98)
                                : (cardMouse.pressed ? Colors.changeA(Colors.pressed, 0.78)
                                : (cardMouse.containsMouse ? Colors.changeA(Colors.fired, 0.62)
                                                        : Colors.changeA(Colors.background, 0.34))
                                )
        border.width: 1
        border.color: card.dragging ? Colors.changeA(Colors.border, 0.82)
                                    : Colors.changeA(Colors.text, 0.09)
        z: card.dragging ? 200 : 0
        scale: root.relayBar.groupDropPreviewActive && card.dragging ? 0.72
                                                                      : (cardMouse.pressed ? 0.98 : 1)
        transformOrigin: Item.Center

        Drag.active: cardMouse.drag.active
        Drag.keys: ["xcshop-element"]
        // Use the pointer's grab point for DropArea hit testing, rather than
        // the card centre.  This makes a target activate when the cursor
        // reaches it, regardless of where the card was picked up.
        Drag.hotSpot.x: cardMouse.mouseX
        Drag.hotSpot.y: cardMouse.mouseY
        Drag.mimeData: ({ "text/plain": root.path })

        Behavior on color { ColorAnimation { duration: 110 } }
        Behavior on border.color { ColorAnimation { duration: 110 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Image {
            id: elementIcon
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
            visible: status === Image.Ready
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 52
            anchors.right: favoriteButton.left
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            XCText {
                width: parent.width
                xcText: root.name
                xcFontSize: 12
                onCenter: false
            }
            XCText {
                width: parent.width
                xcText: root.relativePath
                xcFontSize: 9
                boldFont: false
                onCenter: false
                textColor: Colors.banned
            }
        }

        TextButton {
            id: favoriteButton
            z: 4
            anchors.right: deleteButton.left
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 7
            text: root.relayBar.isFavorite(root.path) ? "★" : "☆"
            textSize: 17
            textColor: root.relayBar.isFavorite(root.path) ? Colors.border : Colors.banned
            buttonColor: Colors.transparent
            firedColor: Colors.changeA(Colors.border, 0.16)
            pressedColor: Colors.changeA(Colors.border, 0.28)
            onClicked: root.relayBar.toggleFavorite(root.recordData)
        }

        TextButton {
            id: deleteButton
            z: 4
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 6
            text: "×"
            textSize: 18
            textColor: Colors.error
            buttonColor: Colors.transparent
            firedColor: Colors.changeA(Colors.error, 0.16)
            pressedColor: Colors.changeA(Colors.error, 0.28)
            onClicked: root.relayBar.removeRecordFromCurrentGroup(root.path)
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            drag.target: card
            drag.threshold: 7
            onPressed: card.suppressClick = false
            onPositionChanged: {
                if (drag.active && !card.dragging) {
                    card.dragging = true
                    card.suppressClick = true
                    root.relayBar.draggedRecord = root.recordData
                    root.relayBar.draggedSourceIndex = root.sourceIndex
                    SignalBus.draggedElementPath = root.path
                    SignalBus.elementDragStateChanged(true)
                }
            }
            onReleased: {
                if (card.dragging) {
                    card.Drag.drop()
                    SignalBus.elementDragStateChanged(false)
                    root.relayBar.draggedRecord = null
                    card.dragging = false
                    card.x = 4
                    card.y = 4
                    Qt.callLater(function() {
                        SignalBus.draggedElementPath = ""
                        root.relayBar.draggedSourceIndex = -1
                        root.relayBar.clearDragTarget()
                        card.suppressClick = false
                    })
                }
            }
            onCanceled: {
                if (card.dragging)
                    SignalBus.elementDragStateChanged(false)
                root.relayBar.draggedRecord = null
                root.relayBar.draggedSourceIndex = -1
                root.relayBar.clearDragTarget()
                SignalBus.draggedElementPath = ""
                card.dragging = false
                card.x = 4
                card.y = 4
                card.suppressClick = false
            }
            onClicked: {
                if (!card.suppressClick)
                    root.relayBar.useRecord(root.recordData)
            }
        }

        DropArea {
            anchors.fill: parent
            keys: ["xcshop-element"]
            onEntered: function(drag) {
                if (root.relayBar.draggedRecord && root.relayBar.draggedSourceIndex !== root.sourceIndex) {
                    root.relayBar.setDragTarget(root.relayBar.currentGroupKey, root.sourceIndex)
                    drag.acceptProposedAction()
                }
            }
            onExited: root.relayBar.clearDragTarget(root.relayBar.currentGroupKey, root.sourceIndex)
            onDropped: function(drop) {
                if (root.relayBar.draggedRecord) {
                    var record = RelayState.clone(root.relayBar.draggedRecord)
                    var targetIndex = root.sourceIndex
                    drop.acceptProposedAction()
                    root.relayBar.clearDragTarget()
                    Qt.callLater(function() { root.relayBar.reorderCurrentGroup(record, targetIndex) })
                }
            }
        }
    }

    Rectangle {
        id: insertionMarker
        readonly property bool atRowStart: root.sourceIndex % root.relayBar.columnCount === 0
        visible: card.reorderTarget
        z: 300
        x: atRowStart ? 4 : 0
        y: atRowStart ? 0 : 6
        width: atRowStart ? root.width - 8 : 3
        height: atRowStart ? 3 : root.height - 12
        radius: 2
        color: Colors.changeA(Colors.border, 0.96)

        Behavior on opacity { NumberAnimation { duration: 100 } }
    }
}
