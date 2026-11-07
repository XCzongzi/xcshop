pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Rectangle{
    id: root
    property int uiscale: 1
    property int containerType: 1
    property var uiPage: null
    color: Colors.transparent

    width: containerImage.sourceSize.width * uiscale
    height: containerImage.sourceSize.height * uiscale


    Image{
        id: containerImage
        anchors.fill: parent
        source: "qrc:/assets/minecraft/gui/container/" + root.containerType + ".png"
        fillMode: Image.PreserveAspectFit
        smooth: false
        mipmap: false
    }

    MouseArea {
        id: drawMouse
        anchors.fill: parent
        z: 2000
        enabled: root.uiPage !== null && root.uiPage.nestingDrawMode
        visible: enabled
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        cursorShape: enabled ? Qt.CrossCursor : Qt.ArrowCursor

        property var strokeEdit: null
        property bool adding: true
        property point lastPoint

        function slotAt(x, y) {
            var positions = Constants.containerSlot[root.containerType]
            for (var index = 0; index < Constants.containerCount[root.containerType]; ++index) {
                var left = positions[index][0] * root.uiscale
                var top = positions[index][1] * root.uiscale
                if (x >= left && x < left + 16 * root.uiscale
                        && y >= top && y < top + 16 * root.uiscale)
                    return index
            }
            return -1
        }

        function paintTo(x, y) {
            if (!strokeEdit)
                return
            // Intersect the whole pointer segment with each slot, so fast moves
            // also paint slots between successive mouse events.
            var positions = Constants.containerSlot[root.containerType]
            var start = [lastPoint.x / root.uiscale, lastPoint.y / root.uiscale]
            var delta = [x / root.uiscale - start[0], y / root.uiscale - start[1]]
            for (var index = 0; index < Constants.containerCount[root.containerType]; ++index) {
                var enter = 0, leave = 1
                for (var axis = 0; axis < 2; ++axis) {
                    var low = positions[index][axis], high = low + 16
                    if (delta[axis] === 0) {
                        if (start[axis] < low || start[axis] >= high)
                            leave = -1
                    } else {
                        var first = (low - start[axis]) / delta[axis]
                        var second = (high - start[axis]) / delta[axis]
                        enter = Math.max(enter, Math.min(first, second))
                        leave = Math.min(leave, Math.max(first, second))
                    }
                }
                if (enter <= leave && root.uiPage.isSlotInSelectedNestedGroup(index) !== adding)
                    root.uiPage.toggleNestedSlot(index, strokeEdit)
            }
            lastPoint = Qt.point(x, y)
        }

        function finishStroke() {
            if (strokeEdit) {
                var edit = strokeEdit
                strokeEdit = null
                root.uiPage.finishWorkspaceEdit(edit)
            }
        }

        onPressed: function(mouse) {
            var index = slotAt(mouse.x, mouse.y)
            if (index < 0) {
                mouse.accepted = false
                return
            }
            root.forceActiveFocus()
            adding = !root.uiPage.isSlotInSelectedNestedGroup(index)
            strokeEdit = root.uiPage.beginWorkspaceEdit([], false, root.uiPage.selectedNestedGroup())
            lastPoint = Qt.point(mouse.x, mouse.y)
            paintTo(mouse.x, mouse.y)
        }
        onPositionChanged: function(mouse) {
            if (pressed)
                paintTo(mouse.x, mouse.y)
        }
        onReleased: function(mouse) {
            paintTo(mouse.x, mouse.y)
            finishStroke()
        }
        onCanceled: finishStroke()
        onEnabledChanged: if (!enabled) finishStroke()
        onWheel: function(wheel) { wheel.accepted = false }
    }

    Repeater{
        model: Constants.containerCount[root.containerType]
        delegate: ItemSlot{
            id: saleSlot
            required property int index
            required property var model
            size: 16 * root.uiscale
            selectionId: "item"
            dragContext: root.uiPage
            slotIndex: index

            x: Constants.containerSlot[root.containerType][index][0] * root.uiscale
            y: Constants.containerSlot[root.containerType][index][1] * root.uiscale

            onActivated: {
                if (root.uiPage)
                    root.uiPage.setCurrentSlot(index)
            }
            onNestedSlotToggled: {
                if (root.uiPage)
                    root.uiPage.toggleNestedSlot(index)
            }
            onSlotItemsDropped: function(sourceSlotIndex) {
                if (root.uiPage)
                    root.uiPage.swapSlotItems(sourceSlotIndex, index)
            }
            onElementSelected: function(filePath) {
                if (root.uiPage)
                    root.uiPage.setSlotPreviewElement(index, filePath)
            }
            onSelectionCleared: {
                if (root.uiPage)
                    root.uiPage.setSlotPreviewElement(index, "")
            }
            onContextMenuRequested: function(x, y) {
                if (!root.uiPage)
                    return
                SignalBus.contextMenuRequested(saleSlot, x, y, [
                    { "text": "删除当前栏位",
                      "shortcutKey": Qt.Key_Delete,
                      "enabled": root.uiPage.slotItems(index).length > 0,
                      "action": function() { root.uiPage.clearSlotItems(index) } }
                ], null)
            }

            function syncFromPage() {
                if (!root.uiPage)
                    return
                setLit(root.uiPage.currentSlotIndex === index)
                nestedPreviewed = root.uiPage.isSlotInSelectedNestedGroup(index)
                nestedOccupied = root.uiPage.isSlotNested(index)
                nestingDrawMode = root.uiPage.nestingDrawMode
                previewItemIndex = root.uiPage.previewItemIndex(index)
                setElement(root.uiPage.previewItemForSlot(index), false)
            }

            Connections {
                target: root.uiPage
                function onCurrentSlotIndexChanged() { saleSlot.syncFromPage() }
                function onSlotItemsChanged(slotIndex) {
                    if (slotIndex === saleSlot.index)
                        saleSlot.syncFromPage()
                }
                function onLayoutDataChanged() { saleSlot.syncFromPage() }
            }

            Component.onCompleted: syncFromPage()
        }
    }
}
