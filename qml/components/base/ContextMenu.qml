pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    anchors.fill: parent
    z: 1000
    visible: opened || closing
    focus: opened

    // 标准菜单项：{ text, icon, enabled, separator, children, shortcutKey, action }
    // children 为数组时会显示二级菜单；contentComponent 用于完全自定义菜单内容。
    property var menuItems: []
    property Component contentComponent: null
    property Item backdropAnchor: null
    property int minimumWidth: 176
    property int itemHeight: 30
    property int horizontalPadding: 6
    property int verticalPadding: 6
    property int edgeMargin: 8
    readonly property int animationDuration: 350 / Global.animationSpeed
    property bool opened: false
    property bool closing: false

    property real menuX: 0
    property real menuY: 0
    property real submenuX: 0
    property real submenuY: 0
    property int activeSubmenuIndex: -1

    readonly property var activeSubmenu: activeSubmenuIndex >= 0 && activeSubmenuIndex < menuItems.length
                                       ? menuItems[activeSubmenuIndex] : null
    readonly property bool submenuOpened: !!(activeSubmenu
                                        && activeSubmenu.children
                                        && activeSubmenu.children.length > 0)
    readonly property var customContentItem: contentLoader.item
    readonly property real customContentWidth: customContentItem
                                               ? Math.max(contentLoader.implicitWidth,
                                                          customContentItem.width || 0) : 0
    readonly property real customContentHeight: customContentItem
                                                ? Math.max(contentLoader.implicitHeight,
                                                           customContentItem.height || 0) : 0

    signal triggered(var item, int index, int parentIndex)
    signal openedAt(real x, real y)
    signal closed()

    component MenuViewport: Flickable {
        id: viewport
        clip: true
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds

        function clampContentY() {
            contentY = Math.max(0, Math.min(contentY, Math.max(0, contentHeight - height)))
        }
        onHeightChanged: clampContentY()
        onContentHeightChanged: clampContentY()

        WheelHandler {
            onWheel: function(event) {
                var delta = event.pixelDelta.y || event.angleDelta.y
                viewport.contentY = Math.max(0, Math.min(viewport.contentY - delta,
                                                        Math.max(0, viewport.contentHeight - viewport.height)))
                event.accepted = true
            }
        }
    }

    function openAt(x, y) {
        backdropAnchor = null
        closeTimer.stop()
        closing = false
        menuX = x
        menuY = y
        activeSubmenuIndex = -1
        menuViewport.contentY = 0
        submenuViewport.contentY = 0
        opened = true
        forceActiveFocus()
        repositionTimer.restart()
        openedAt(x, y)
    }

    function openFor(target, x, y) {
        if (!target)
            return

        var point = target.mapToItem(root, x, y)
        openAt(point.x, point.y)
        backdropAnchor = target
    }

    function close() {
        if (!opened || closing)
            return

        opened = false
        activeSubmenuIndex = -1
        closing = true
        closeTimer.restart()
    }

    function invoke(item, index, parentIndex) {
        if (!item || item.enabled === false || item.separator)
            return

        if (typeof item.action === "function")
            item.action()
        triggered(item, index, parentIndex)
        close()
    }

    function openSubmenu(index, row) {
        var item = menuItems[index]
        if (!item || !item.children || !item.children.length) {
            activeSubmenuIndex = -1
            return
        }

        if (activeSubmenuIndex !== index)
            submenuViewport.contentY = 0
        activeSubmenuIndex = index
        var point = row.mapToItem(root, 0, 0)
        submenuY = point.y - verticalPadding
        repositionSubmenu()
    }

    function reposition() {
        menuX = Math.max(edgeMargin, Math.min(menuX, width - menuSurface.width - edgeMargin))
        menuY = Math.max(edgeMargin, Math.min(menuY, height - menuSurface.height - edgeMargin))
        repositionSubmenu()
    }

    function repositionSubmenu() {
        if (!submenuOpened)
            return

        var fitsRight = menuSurface.x + menuSurface.width + 4 + submenuSurface.width
                        <= width - edgeMargin
        submenuX = fitsRight ? menuSurface.x + menuSurface.width + 4
                             : menuSurface.x - submenuSurface.width - 4
        submenuX = Math.max(edgeMargin, Math.min(submenuX, width - submenuSurface.width - edgeMargin))
        submenuY = Math.max(edgeMargin, Math.min(submenuY, height - submenuSurface.height - edgeMargin))
    }

    onWidthChanged: if (opened) repositionTimer.restart()
    onHeightChanged: if (opened) repositionTimer.restart()
    onSubmenuOpenedChanged: if (submenuOpened) repositionTimer.restart()

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
            return
        }
        for (var i = 0; i < menuItems.length; ++i) {
            var item = menuItems[i]
            if (item.shortcutKey === event.key && item.enabled !== false) {
                invoke(item, i, -1)
                event.accepted = true
                return
            }
            var children = item.children || []
            for (var childIndex = 0; childIndex < children.length; ++childIndex) {
                if (children[childIndex].shortcutKey === event.key
                        && children[childIndex].enabled !== false) {
                    invoke(children[childIndex], childIndex, i)
                    event.accepted = true
                    return
                }
            }
        }
    }

    Timer {
        id: repositionTimer
        interval: 0
        onTriggered: root.reposition()
    }

    Timer {
        id: closeTimer
        interval: root.animationDuration
        onTriggered: {
            root.closing = false
            root.closed()
        }
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "#000000"
        opacity: root.opened ? 0.16 : 0

        Behavior on opacity {
            NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onClicked: function(mouse) {
                root.close()
                mouse.accepted = true
            }
        }
    }

    FrostedSurface {
        id: menuSurface
        objectName: "contextMenuSurface"
        backdropAnchor: root.backdropAnchor
        visible: root.opened || root.closing
        x: root.menuX
        y: root.menuY
        opacity: root.opened ? 1 : 0
        scale: root.opened ? 1 : 0.96
        transformOrigin: Item.TopLeft
        width: Math.min(Math.max(root.minimumWidth, root.customContentWidth + root.horizontalPadding * 2,
                                menuColumn.naturalWidth + root.horizontalPadding * 2),
                        Math.max(0, root.width - root.edgeMargin * 2))
        height: Math.min(Math.max(root.customContentHeight, menuColumn.implicitHeight)
                         + root.verticalPadding * 2, Math.max(0, root.height - root.edgeMargin * 2))
        radius: 10
        border.width: 1
        border.color: Colors.changeA(Colors.outline, 0.12)
        onWidthChanged: if (root.opened) repositionTimer.restart()
        onHeightChanged: if (root.opened) repositionTimer.restart()

        Behavior on opacity {
            NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutBack }
        }

        Loader {
            id: contentLoader
            x: root.horizontalPadding
            y: root.verticalPadding
            visible: root.contentComponent !== null
            sourceComponent: root.contentComponent
        }

        MenuViewport {
            id: menuViewport
            objectName: "menuViewport"
            x: root.horizontalPadding
            y: root.verticalPadding
            width: Math.max(0, parent.width - root.horizontalPadding * 2)
            height: Math.max(0, parent.height - root.verticalPadding * 2)
            contentHeight: menuColumn.implicitHeight
            visible: root.contentComponent === null
            onContentYChanged: if (root.opened) root.activeSubmenuIndex = -1

            Column {
                id: menuColumn
                // Column's implicit width follows the rows' assigned width.
                // Measure their natural widths independently of the viewport.
                readonly property real naturalWidth: {
                    var maximum = 0
                    for (var child of children)
                        maximum = Math.max(maximum, child.implicitWidth)
                    return maximum
                }
                width: parent.width
                spacing: 1

                Repeater {
                    model: root.menuItems

                    delegate: Item {
                        id: menuRow
                        required property int index
                        required property var modelData
                        readonly property var entry: modelData
                        readonly property bool hasChildren: !!(entry.children && entry.children.length > 0)
                        property bool hovered: false
                        property bool pressed: false

                        width: menuColumn.width
                        height: entry.separator ? 7 : root.itemHeight
                        implicitWidth: entry.separator ? 0 : menuLabel.x + menuLabel.implicitWidth
                                       + (hasChildren ? 28 : 11)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 10
                            x: 5
                            height: 1
                            visible: menuRow.entry.separator === true
                            color: Colors.changeA(Colors.outline, 0.12)
                        }

                        Item {
                            x: 3
                            z: 0
                            width: parent.width - x * 2
                            height: parent.height
                            visible: !menuRow.entry.separator
                            scale: menuRow.pressed ? 0.985 : 1
                            Behavior on scale { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }

                            ButtonStateOverlay {
                                hoverColor: Colors.changeA(Colors.fired, 0.44)
                                pressedColor: Colors.changeA(Colors.pressed, 0.78)
                                hovered: menuRow.hovered
                                pressed: menuRow.pressed
                                stateEnabled: menuRow.entry.enabled !== false
                                duration: 350
                                cornerRadius: 6
                            }
                        }

                        Rectangle {
                            x: 3
                            anchors.verticalCenter: parent.verticalCenter
                            z: 1
                            width: 2
                            height: Math.max(0, menuRow.pressed ? parent.height - 8
                                                                : parent.height - 14)
                            radius: width / 2
                            visible: !menuRow.entry.separator
                            color: Colors.border
                            opacity: menuRow.pressed ? 1 : (menuRow.hovered ? 0.78 : 0)

                            Behavior on opacity { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
                        }

                        ThemedIcon {
                            id: itemIcon
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            visible: !menuRow.entry.separator && menuRow.entry.icon !== undefined
                            iconSource: visible ? menuRow.entry.icon : ""
                            opacity: menuRow.entry.enabled === false ? 0.42 : 0.85
                            mipmap: true
                        }

                        XCText {
                            id: menuLabel
                            x: itemIcon.visible ? itemIcon.x + itemIcon.width + 8 : 11
                            width: parent.width - x - (menuRow.hasChildren ? 28 : 11)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !menuRow.entry.separator
                            xcText: menuRow.entry.text || ""
                            xcFontSize: 13
                            onCenter: false
                            boldFont: false
                            textColor: menuRow.entry.enabled === false
                                       ? Colors.changeA(Colors.banned, 0.62) : Colors.text
                        }

                        XCText {
                            anchors.right: parent.right
                            anchors.rightMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !menuRow.entry.separator && menuRow.hasChildren
                            xcText: ">"
                            xcFontSize: 14
                            boldFont: false
                            textColor: Colors.changeA(Colors.text, 0.74)
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !menuRow.entry.separator && menuRow.entry.enabled !== false
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                menuRow.hovered = true
                                if (menuRow.hasChildren)
                                    root.openSubmenu(menuRow.index, menuRow)
                                else
                                    root.activeSubmenuIndex = -1
                            }
                            onExited: {
                                menuRow.hovered = false
                                menuRow.pressed = false
                            }
                            onPressed: menuRow.pressed = true
                            onReleased: menuRow.pressed = false
                            onClicked: {
                                if (!menuRow.hasChildren)
                                    root.invoke(menuRow.entry, menuRow.index, -1)
                            }
                        }
                    }
                }
            }
        }
    }

    FrostedSurface {
        id: submenuSurface
        objectName: "contextSubmenuSurface"
        backdropAnchor: root.backdropAnchor
        visible: root.submenuOpened && root.opened
        x: root.submenuX
        y: root.submenuY
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.97
        transformOrigin: Item.TopLeft
        width: Math.min(Math.max(root.minimumWidth, submenuColumn.naturalWidth + root.horizontalPadding * 2),
                        Math.max(0, root.width - root.edgeMargin * 2))
        height: Math.min(submenuColumn.implicitHeight + root.verticalPadding * 2,
                         Math.max(0, root.height - root.edgeMargin * 2))
        radius: 10
        border.width: 1
        border.color: Colors.changeA(Colors.outline, 0.12)
        onWidthChanged: if (root.opened) repositionTimer.restart()
        onHeightChanged: if (root.opened) repositionTimer.restart()

        Behavior on opacity {
            NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutBack }
        }

        MenuViewport {
            id: submenuViewport
            objectName: "submenuViewport"
            x: root.horizontalPadding
            y: root.verticalPadding
            width: Math.max(0, parent.width - root.horizontalPadding * 2)
            height: Math.max(0, parent.height - root.verticalPadding * 2)
            contentHeight: submenuColumn.implicitHeight

            Column {
                id: submenuColumn
                readonly property real naturalWidth: {
                    var maximum = 0
                    for (var child of children)
                        maximum = Math.max(maximum, child.implicitWidth)
                    return maximum
                }
                width: parent.width
                spacing: 1

                Repeater {
                    model: root.submenuOpened ? root.activeSubmenu.children : []

                    delegate: Item {
                        id: submenuRow
                        required property int index
                        required property var modelData
                        readonly property var entry: modelData
                        property bool hovered: false
                        property bool pressed: false

                        width: submenuColumn.width
                        height: entry.separator ? 7 : root.itemHeight
                        implicitWidth: entry.separator ? 0 : submenuLabel.implicitWidth + 22

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 10
                            x: 5
                            height: 1
                            visible: submenuRow.entry.separator === true
                            color: Colors.changeA(Colors.outline, 0.12)
                        }

                        Item {
                            x: 3
                            z: 0
                            width: parent.width - x * 2
                            height: parent.height
                            visible: !submenuRow.entry.separator
                            scale: submenuRow.pressed ? 0.985 : 1
                            Behavior on scale { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }

                            ButtonStateOverlay {
                                hoverColor: Colors.changeA(Colors.fired, 0.44)
                                pressedColor: Colors.changeA(Colors.pressed, 0.78)
                                hovered: submenuRow.hovered
                                pressed: submenuRow.pressed
                                stateEnabled: submenuRow.entry.enabled !== false
                                duration: 350
                                cornerRadius: 6
                            }
                        }

                        Rectangle {
                            x: 3
                            anchors.verticalCenter: parent.verticalCenter
                            z: 1
                            width: 2
                            height: Math.max(0, submenuRow.pressed ? parent.height - 8
                                                                   : parent.height - 14)
                            radius: width / 2
                            visible: !submenuRow.entry.separator
                            color: Colors.border
                            opacity: submenuRow.pressed ? 1 : (submenuRow.hovered ? 0.78 : 0)

                            Behavior on opacity { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
                        }

                        XCText {
                            id: submenuLabel
                            x: 11
                            width: parent.width - x - 11
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !submenuRow.entry.separator
                            xcText: submenuRow.entry.text || ""
                            xcFontSize: 13
                            onCenter: false
                            boldFont: false
                            textColor: submenuRow.entry.enabled === false
                                       ? Colors.changeA(Colors.banned, 0.62) : Colors.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !submenuRow.entry.separator && submenuRow.entry.enabled !== false
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: submenuRow.hovered = true
                            onExited: {
                                submenuRow.hovered = false
                                submenuRow.pressed = false
                            }
                            onPressed: submenuRow.pressed = true
                            onReleased: submenuRow.pressed = false
                            onClicked: root.invoke(submenuRow.entry, submenuRow.index,
                                                   root.activeSubmenuIndex)
                        }
                    }
                }
            }
        }
    }
}
