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

    Repeater{
        model: Constants.containerCount[root.containerType]
        delegate: ItemSlot{
            id: saleSlot
            required property int index
            required property var model
            size: 16 * root.uiscale
            selectionId: "item"

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
            onElementSelected: function(filePath) {
                if (root.uiPage)
                    root.uiPage.setSlotPreviewElement(index, filePath)
            }
            onSelectionCleared: {
                if (root.uiPage)
                    root.uiPage.setSlotPreviewElement(index, "")
            }

            function syncFromPage() {
                if (!root.uiPage)
                    return
                setLit(root.uiPage.currentSlotIndex === index)
                nestedPreviewed = root.uiPage.isSlotInSelectedNestedGroup(index)
                nestedOccupied = root.uiPage.isSlotNested(index)
                nestingDrawMode = root.uiPage.nestingDrawMode
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
