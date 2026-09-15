import QtQuick
import xcshop

Rectangle {
    id: root

    property int desiredWidth: 400
    property int minimumWidth: 260
    property int maximumWidth: minimumWidth
    property var uiPage: null

    signal widthRequested(int width)
    signal widthResizeFinished()

    width: Math.min(desiredWidth, maximumWidth)
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
