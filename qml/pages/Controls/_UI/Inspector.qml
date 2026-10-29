import QtQuick
import QtQuick.Window
import xcshop

ContentSurface {
    id: root
    hoverEffectsEnabled: true

    property int desiredWidth: 400
    property int minimumWidth: 260
    property int maximumWidth: minimumWidth
    property var uiPage: null
    property alias selectedSection: propertyEditor.selected

    signal widthRequested(int width)
    signal widthResizeFinished()

    width: Math.min(desiredWidth, maximumWidth)

    function finishEditing() {
        var item = root.Window.window ? root.Window.window.activeFocusItem : null
        while (item) {
            if (item === root) {
                // Commit the old context before a slot or group is changed.
                root.forceActiveFocus()
                return
            }
            item = item.parent
        }
    }

    function showSlotEditor() { propertyEditor.selectOption(1) }
    function showLayoutEditor() { propertyEditor.selectOption(2) }

    function leaveLayoutEditor() {
        if (propertyEditor.selected === 2)
            propertyEditor.selectOption(root.uiPage && root.uiPage.currentSlotIndex >= 0 ? 1 : 0)
    }

    function clearSlotEditor() {
        if (propertyEditor.selected !== 1)
            return
        var group = root.uiPage ? root.uiPage.selectedNestedGroup() : null
        propertyEditor.selectOption(group && root.uiPage.isNestedGroupLayoutInputEnabled(group.id) ? 2 : 0)
    }

    XCText {
        x: 18
        y: 16
        width: parent.width - 36
        xcText: "检查器"
        xcFontSize: 18
        onCenter: false
    }

    MultiPropertyEdit {
        id: propertyEditor
        x: 16
        y: 32
        width: parent.width - 32
        height: parent.height - y - 16
        contentPadding: 0
        options: ["全局属性", "当前栏位", "布局输入器"]
        GlobalProperties {
            id: globalProperties
            visible: propertyEditor.selected === 0
            uiPage: root.uiPage
        }

        CurrentSlotProperties {
            id: currentSlotProperties
            visible: propertyEditor.selected === 1
            uiPage: root.uiPage
        }

        LayoutInput {
            id: layoutInput
            visible: propertyEditor.selected === 2
            uiPage: root.uiPage
        }
    }

    ResizeHandle {
        id: resizeHandle
        z: 10
        horizontal: false
        x: -width / 2
        width: 12
        height: parent.height

        property int pressWidth: 0

        onDragStarted: pressWidth = root.width
        onDragMoved: function(delta) {
            root.widthRequested(Math.max(
                                    root.minimumWidth,
                                    Math.min(root.maximumWidth,
                                             pressWidth - delta)))
        }
        onDragFinished: root.widthResizeFinished()
    }
}
