pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root

    property var uiPage: null
    readonly property int slotIndex: uiPage ? uiPage.currentSlotIndex : -1
    readonly property bool hasCurrentSlot: uiPage && slotIndex >= 0

    width: parent ? parent.width : 0
    height: parent ? parent.height - 16 : 0
    y: 16

    ListModel { id: saleItemModel }

    function rebuildModel() {
        saleItemModel.clear()
        if (!root.hasCurrentSlot)
            return
        var items = root.uiPage.slotItems(root.slotIndex)
        for (var index = 0; index < items.length; ++index)
            saleItemModel.append({ "serial": index, "revision": 0 })
        Qt.callLater(root.syncEditors)
    }

    function syncEditors() {
        if (!root.hasCurrentSlot)
            return
        for (var index = 0; index < saleItemModel.count; ++index)
            saleItemModel.setProperty(index, "revision",
                                      saleItemModel.get(index).revision + 1)
    }

    Flickable {
        id: editorFlickable
        anchors.fill: parent
        visible: root.hasCurrentSlot
        clip: true
        contentWidth: width
        contentHeight: editorColumn.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: editorColumn
            width: editorFlickable.width
            spacing: 10

            XCText {
                width: parent.width
                xcText: "container." + root.slotIndex
                onCenter: false
                xcFontSize: 15
            }

            TextButton {
                id: addButton
                width: parent.width
                height: 40
                radius: 8
                enabled: root.hasCurrentSlot
                text: root.hasCurrentSlot
                      ? "＋  新建在售物品"
                      : "请先选择一个物品槽"
                textSize: 13
                boldFont: false
                textColor: enabled ? Colors.text : Colors.banned
                buttonColor: Colors.changeA(Colors.background, 0.38)
                firedColor: Colors.changeA(Colors.fired, 0.62)
                pressedColor: Colors.changeA(Colors.border, 0.55)
                onClicked: root.uiPage.addSaleItem(root.slotIndex)
            }

            Repeater {
                id: saleItemRepeater
                model: saleItemModel

                delegate: SaleItemEditor {
                    required property int index
                    required property var model
                    required property int revision

                    width: editorColumn.width
                    itemIndex: index
                    itemCount: saleItemModel.count
                    preview: root.uiPage.previewItemIndex(root.slotIndex) === index

                    onMoveUpRequested: function(index) {
                        root.uiPage.moveSaleItem(root.slotIndex, index, index - 1)
                    }
                    onMoveDownRequested: function(index) {
                        root.uiPage.moveSaleItem(root.slotIndex, index, index + 1)
                    }
                    onDeleteRequested: function(index) {
                        root.uiPage.removeSaleItem(root.slotIndex, index)
                    }
                    onPreviewChangeRequested: function(index, checked) {
                        root.uiPage.setPreviewSaleItem(root.slotIndex, index, checked)
                    }
                    onItemChangeRequested: function(index, filePath) {
                        root.uiPage.updateSaleItemElement(root.slotIndex, index, filePath)
                    }
                    onFilterChangeRequested: function(index, scoreboardName,
                                                       targetName, scoreRange) {
                        root.uiPage.updateSaleItemFilter(root.slotIndex, index,
                                                         scoreboardName,
                                                         targetName, scoreRange)
                    }
                    onMacrosChangeRequested: function(index, macros) {
                        root.uiPage.updateSaleItemMacros(root.slotIndex, index, macros)
                    }

                    function syncFromPage() {
                        var items = root.uiPage.slotItems(root.slotIndex)
                        if (index < items.length)
                            syncData(items[index])
                    }

                    onRevisionChanged: syncFromPage()
                    Component.onCompleted: syncFromPage()
                }
            }
        }

        onContentYChanged: {
            // While the handle is pressed it is the source of truth. Feeding
            // the rounded content offset back into it makes a held handle
            // creep toward its previous position.
            if (!slotScrollBar.dragging)
                slotScrollBar.setContentOffset(contentY)
        }
        onMovementStarted: slotScrollBar.animatePosition = false
        onMovementEnded: slotScrollBar.animatePosition = true
    }

    XCText {
        visible: !root.hasCurrentSlot
        width: parent.width
        xcText: "未选择待编辑的栏位"
        onCenter: false
        xcFontSize: 13
        boldFont: false
        textColor: Colors.banned
    }

    ScrollBar {
        id: slotScrollBar
        visible: root.hasCurrentSlot
        z: 1
        x: parent.width + 8
        height: parent.height
        content_height: editorFlickable.contentHeight
        layout_determines: root.slotIndex
        onHeight_outputChanged: {
            if (!editorFlickable.moving)
                editorFlickable.contentY = height_output
        }
    }

    Connections {
        target: root.uiPage

        function onCurrentSlotIndexChanged() {
            editorFlickable.contentY = 0
            root.rebuildModel()
        }

        function onSlotItemsChanged(changedSlotIndex) {
            if (changedSlotIndex !== root.slotIndex)
                return
            var itemCount = root.uiPage.slotItems(root.slotIndex).length
            while (saleItemModel.count < itemCount) {
                saleItemModel.append({
                    "serial": saleItemModel.count,
                    "revision": 0
                })
            }
            if (saleItemModel.count > itemCount)
                saleItemModel.remove(itemCount, saleItemModel.count - itemCount)
            root.syncEditors()
        }
    }

    Component.onCompleted: rebuildModel()
}
