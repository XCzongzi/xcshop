import QtQuick
import xcshop

Item {
    id: root
    clip: true

    property int minimumScale: 1
    property int maximumScale: 30
    property int containerType: -1
    property var uiPage: null
    property bool viewWasManipulated: false

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function minimumContainerX() {
        return -container.width / 2
    }

    function maximumContainerX() {
        return width - container.width / 2
    }

    function minimumContainerY() {
        return -container.height / 2
    }

    function maximumContainerY() {
        return height - container.height / 2
    }

    function constrainView() {
        container.x = clamp(container.x, minimumContainerX(), maximumContainerX())
        container.y = clamp(container.y, minimumContainerY(), maximumContainerY())
    }

    function centerView() {
        container.x = (width - container.width) / 2
        container.y = (height - container.height) / 2
        constrainView()
    }

    function updateViewAfterResize() {
        if (viewWasManipulated)
            constrainView()
        else
            centerView()
    }

    onWidthChanged: updateViewAfterResize()
    onHeightChanged: updateViewAfterResize()

    ContainerUI {
        id: container
        uiscale: root.minimumScale
        // Keep a valid value while a newly created UI is awaiting its
        // container choice; the canvas itself remains hidden until then.
        containerType: root.containerType >= 0 ? root.containerType : 0
        uiPage: root.uiPage
        visible: root.containerType >= 0

        onWidthChanged: root.updateViewAfterResize()
        onHeightChanged: root.updateViewAfterResize()

        Component.onCompleted: root.centerView()
    }

    MouseArea {
        id: viewMouse
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true

        property real pressX: 0
        property real pressY: 0
        property real containerX: 0
        property real containerY: 0

        function isOverContainer(x, y) {
            return x >= container.x && x <= container.x + container.width
                    && y >= container.y && y <= container.y + container.height
        }

        readonly property bool cursorOverContainer: isOverContainer(mouseX, mouseY)

        cursorShape: pressed ? Qt.ClosedHandCursor
                             : (cursorOverContainer ? Qt.ArrowCursor
                                                    : Qt.OpenHandCursor)

        onPressed: function(mouse) {
            pressX = mouse.x
            pressY = mouse.y
            containerX = container.x
            containerY = container.y
            root.viewWasManipulated = true
        }

        onPositionChanged: function(mouse) {
            if (!pressed)
                return

            container.x = containerX + mouse.x - pressX
            container.y = containerY + mouse.y - pressY
            root.constrainView()
        }

        onWheel: function(wheel) {
            var delta = wheel.angleDelta.y
            if (delta === 0)
                delta = wheel.pixelDelta.y
            if (delta === 0)
                return

            var previousScale = container.uiscale
            var scaleStep = delta > 0 ? 1 : -1
            var nextScale = root.clamp(previousScale + scaleStep,
                                       root.minimumScale, root.maximumScale)
            if (nextScale === previousScale)
                return

            // Keep the pixel under the cursor fixed while zooming.
            var contentX = (wheel.x - container.x) / previousScale
            var contentY = (wheel.y - container.y) / previousScale
            container.uiscale = nextScale
            container.x = wheel.x - contentX * nextScale
            container.y = wheel.y - contentY * nextScale
            root.viewWasManipulated = true
            root.constrainView()
            wheel.accepted = true
        }
    }

}
