pragma ComponentBehavior: Bound
import QtQuick
import xcshop

ContentSurface {
    id: root
    hoverEffectsEnabled: true

    property var uiPage: null
    property int draggedGroupIndex: -1
    property int dragTargetIndex: -1
    readonly property int layoutRevision: uiPage ? uiPage.layoutRevision : 0

    readonly property bool nestedPreview: uiPage
                                          && uiPage.selectedNestedGroupId.length > 0
    readonly property var selectedGroup: {
        return root.layoutRevision >= 0 && nestedPreview
                ? uiPage.selectedNestedGroup() : null
    }
    readonly property bool selectedGroupInputEnabled: root.layoutRevision >= 0
                                                    && root.uiPage && root.selectedGroup
                                                    && root.uiPage.isNestedGroupLayoutInputEnabled(
                                                            root.selectedGroup.id)

    height: 140
    clip: true

    ListModel { id: nestedGroupModel }

    function rebuildGroupModel() {
        nestedGroupModel.clear()
        if (!root.uiPage)
            return
        var groups = root.uiPage.nestedGroups()
        for (var index = 0; index < groups.length; ++index) {
            nestedGroupModel.append({
                "groupId": groups[index].id,
                "groupName": groups[index].name
            })
        }
        Qt.callLater(root.revealSelectedGroup)
    }

    function revealSelectedGroup() {
        if (!root.uiPage)
            return
        tabFlickable.setContentX(tabFlickable.contentX)
        var index = root.uiPage.nestedGroupIndex(root.uiPage.selectedNestedGroupId)
        var item = index >= 0 ? nestedGroupRepeater.itemAt(index) : null
        if (!item)
            return
        var itemLeft = tabRow.x + item.x
        var itemRight = itemLeft + item.width
        var visibleLeft = tabFlickable.contentX + tabFlickable.edgeInset
        var visibleRight = tabFlickable.contentX + tabFlickable.width
                - tabFlickable.edgeInset
        if (itemLeft < visibleLeft)
            tabFlickable.setContentX(itemLeft - tabFlickable.edgeInset)
        else if (itemRight > visibleRight)
            tabFlickable.setContentX(itemRight - tabFlickable.width
                                     + tabFlickable.edgeInset)
    }

    function syncEditors() {
        if (!root.uiPage)
            return
        var placeholder = root.uiPage.placeholderData()
        placeholderEnabled.checked = placeholder.enabled === true
        placeholderSelection.setElement(placeholder.element || "", false)

        var group = root.uiPage.selectedNestedGroup()
        if (!group)
            return
        nestedEnabled.checked = group.enabled === true
        nestedSelection.setElement(group.element || "", false)
        var filter = group.filter || ({})
        nestedFilter.setValues(filter.scoreboard, filter.target, filter.score)
    }

    function refresh() {
        root.rebuildGroupModel()
        Qt.callLater(root.syncEditors)
    }

    function showGroupContextMenu(target, x, y, groupId, groupName) {
        SignalBus.contextMenuRequested(target, x, y, [
            { "text": "重命名", "action": function() {
                root.requestRename(groupId, groupName)
            } },
            { "text": "删除", "action": function() {
                root.requestDelete(groupId, groupName)
            } }
        ], null)
    }

    function requestRename(groupId, groupName) {
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupTextInput,
            "properties": {
                "title": "重命名嵌套组",
                "content": "请输入新的嵌套组名称",
                "value": groupName,
                "confirmText": "重命名"
            },
            "callback": function(result) {
                if (result !== null && result !== undefined && root.uiPage)
                    root.uiPage.renameNestedGroup(groupId, result)
            }
        })
    }

    function requestDelete(groupId, groupName) {
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupNotice,
            "properties": {
                "title": "删除嵌套组",
                "content": "确定删除嵌套组“" + groupName + "”吗？",
                "doubleButton": true
            },
            "callback": function(result) {
                if (result === 1 && root.uiPage)
                    root.uiPage.removeNestedGroup(groupId)
            }
        })
    }

    XCText {
        x: 16
        y: 12
        xcText: "布局管理"
        xcFontSize: 18
        onCenter: false
    }

    Rectangle {
        id: basicTab
        x: 112
        y: 8
        width: 54
        height: 30
        radius: 7
        color: !root.nestedPreview
               ? Colors.changeA(Colors.border, 0.28)
               : (basicMouse.containsMouse
                  ? Colors.changeA(Colors.fired, 0.48)
                  : Colors.changeA(Colors.background, 0.25))
        border.width: !root.nestedPreview ? 1 : 0
        border.color: Colors.changeA(Colors.border, 0.76)

        Behavior on color { ColorAnimation { duration: 120 / Global.animationSpeed } }

        XCText {
            anchors.centerIn: parent
            xcText: "基本"
            xcFontSize: 12
            boldFont: false
            textColor: !root.nestedPreview ? Colors.accentText : Colors.text
        }

        MouseArea {
            id: basicMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.uiPage) root.uiPage.selectBasicLayout()
        }
    }

    Rectangle {
        x: 172
        y: 13
        width: 1
        height: 20
        color: Colors.changeA(Colors.outline, 0.18)
    }

    Flickable {
        id: tabFlickable
        readonly property bool overflowing: tabRow.width > width
        readonly property real edgeInset: overflowing ? 26 : 0

        function setContentX(value) {
            contentX = Math.max(0, Math.min(contentWidth - width, value))
        }

        function scrollPage(direction) {
            setContentX(contentX + direction * Math.max(84, width * 0.7))
        }

        anchors.left: parent.left
        anchors.leftMargin: 180
        anchors.right: addGroupButton.left
        anchors.rightMargin: 6
        y: 8
        height: 34
        clip: true
        contentWidth: tabRow.width + edgeInset * 2
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        onWidthChanged: Qt.callLater(root.revealSelectedGroup)

        WheelHandler {
            target: null
            onWheel: function(event) {
                var delta = event.angleDelta.x !== 0
                        ? event.angleDelta.x : event.angleDelta.y
                if (delta === 0)
                    delta = event.pixelDelta.x !== 0
                            ? event.pixelDelta.x : event.pixelDelta.y
                tabFlickable.setContentX(tabFlickable.contentX - delta)
                event.accepted = true
            }
        }

        Row {
            id: tabRow
            x: tabFlickable.edgeInset
            height: parent.height
            spacing: 5

            Repeater {
                id: nestedGroupRepeater
                model: nestedGroupModel

                delegate: Item {
                    id: groupTabDelegate
                    required property int index
                    required property string groupId
                    required property string groupName

                    readonly property bool selected: root.uiPage
                                                     && root.uiPage.selectedNestedGroupId === groupId
                    width: Math.max(68, Math.min(150, groupLabel.implicitWidth + 24))
                    height: 30

                    Rectangle {
                        id: groupTabCard
                        width: parent.width
                        height: parent.height
                        radius: 7
                        z: groupMouse.drag.active ? 20 : 0
                        color: groupTabDelegate.selected
                               ? Colors.changeA(Colors.border, 0.28)
                               : (groupMouse.containsMouse
                                  ? Colors.changeA(Colors.fired, 0.48)
                                  : Colors.changeA(Colors.background, 0.25))
                        border.width: groupTabDelegate.selected || groupMouse.drag.active ? 1 : 0
                        border.color: groupMouse.drag.active
                                      ? Colors.border : Colors.changeA(Colors.border, 0.72)
                        scale: groupMouse.pressed ? 0.98 : 1

                        Drag.active: groupMouse.drag.active
                                     && root.draggedGroupIndex === groupTabDelegate.index
                        Drag.keys: ["xcshop-nested-group"]
                        Drag.hotSpot.x: groupMouse.mouseX
                        Drag.hotSpot.y: groupMouse.mouseY

                        Behavior on color { ColorAnimation { duration: 120 / Global.animationSpeed } }
                        Behavior on scale { NumberAnimation { duration: 90 / Global.animationSpeed } }

                        XCText {
                            id: groupLabel
                            anchors.centerIn: parent
                            width: parent.width - 16
                            xcText: groupTabDelegate.groupName
                            xcFontSize: 12
                            boldFont: false
                            elide: Text.ElideRight
                            textColor: groupTabDelegate.selected ? Colors.accentText : Colors.text
                        }

                        MouseArea {
                            id: groupMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            drag.target: (pressedButtons & Qt.LeftButton) ? groupTabCard : null
                            drag.axis: Drag.XAxis
                            drag.threshold: 7

                            property bool suppressClick: false

                            onPressed: function(mouse) {
                                suppressClick = false
                                if (mouse.button === Qt.LeftButton)
                                    root.draggedGroupIndex = groupTabDelegate.index
                            }
                            onPositionChanged: {
                                if (drag.active)
                                    suppressClick = true
                            }
                            onClicked: function(mouse) {
                                if (suppressClick)
                                    return
                                if (mouse.button === Qt.RightButton)
                                    root.showGroupContextMenu(groupTabCard, mouse.x, mouse.y,
                                                              groupTabDelegate.groupId,
                                                              groupTabDelegate.groupName)
                                else if (root.uiPage)
                                    root.uiPage.selectNestedGroup(groupTabDelegate.groupId)
                            }
                            onReleased: {
                                if (drag.active)
                                    groupTabCard.Drag.drop()
                                groupTabCard.x = 0
                                groupTabCard.y = 0
                                root.draggedGroupIndex = -1
                                root.dragTargetIndex = -1
                                Qt.callLater(function() { groupMouse.suppressClick = false })
                            }
                            onCanceled: {
                                groupTabCard.Drag.cancel()
                                groupTabCard.x = 0
                                groupTabCard.y = 0
                                root.draggedGroupIndex = -1
                                root.dragTargetIndex = -1
                                suppressClick = false
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["xcshop-nested-group"]
                        onEntered: function(drag) {
                            if (root.draggedGroupIndex >= 0
                                    && root.draggedGroupIndex !== groupTabDelegate.index) {
                                root.dragTargetIndex = groupTabDelegate.index
                                drag.acceptProposedAction()
                            }
                        }
                        onExited: {
                            if (root.dragTargetIndex === groupTabDelegate.index)
                                root.dragTargetIndex = -1
                        }
                        onDropped: function(drop) {
                            var fromIndex = root.draggedGroupIndex
                            var toIndex = groupTabDelegate.index
                            drop.acceptProposedAction()
                            if (root.uiPage)
                                Qt.callLater(function() {
                                    root.uiPage.moveNestedGroup(fromIndex, toIndex)
                                })
                        }
                    }

                    Rectangle {
                        visible: root.dragTargetIndex === groupTabDelegate.index
                                 && root.draggedGroupIndex !== groupTabDelegate.index
                        z: 30
                        x: root.draggedGroupIndex < groupTabDelegate.index ? parent.width - 2 : -2
                        y: 3
                        width: 3
                        height: parent.height - 6
                        radius: 2
                        color: Colors.border
                    }
                }
            }

        }
    }

    TextButton {
        visible: tabFlickable.overflowing
        enabled: tabFlickable.contentX > 0.5
        z: 40
        x: tabFlickable.x
        y: 9
        width: 24
        height: 28
        radius: 7
        text: "‹"
        textSize: 18
        boldFont: false
        buttonColor: Colors.changeA(Colors.card, 0.96)
        firedColor: Colors.changeA(Colors.border, 0.20)
        pressedColor: Colors.changeA(Colors.border, 0.34)
        onClicked: tabFlickable.scrollPage(-1)
    }

    TextButton {
        visible: tabFlickable.overflowing
        enabled: tabFlickable.contentX
                 < tabFlickable.contentWidth - tabFlickable.width - 0.5
        z: 40
        x: tabFlickable.x + tabFlickable.width - width
        y: 9
        width: 24
        height: 28
        radius: 7
        text: "›"
        textSize: 18
        boldFont: false
        buttonColor: Colors.changeA(Colors.card, 0.96)
        firedColor: Colors.changeA(Colors.border, 0.20)
        pressedColor: Colors.changeA(Colors.border, 0.34)
        onClicked: tabFlickable.scrollPage(1)
    }

    TextButton {
        id: addGroupButton
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 8
        width: 30
        height: 30
        radius: 7
        text: "+"
        textSize: 20
        boldFont: false
        textColor: Colors.accentText
        buttonColor: Colors.changeA(Colors.background, 0.25)
        firedColor: Colors.changeA(Colors.border, 0.20)
        pressedColor: Colors.changeA(Colors.border, 0.34)
        onClicked: if (root.uiPage) root.uiPage.addNestedGroup()
    }

    Rectangle {
        x: 12
        y: 47
        width: parent.width - 24
        height: 1
        color: Colors.changeA(Colors.outline, 0.09)
    }

    Flickable {
        id: basicEditor
        visible: !root.nestedPreview
        x: 1
        y: 49
        width: parent.width - 2
        height: Math.max(0, parent.height - y - 8)
        clip: true
        contentWidth: width
        contentHeight: height
        interactive: false

        Item {
            id: basicContent
            width: basicEditor.width
            height: basicEditor.height

            XCText {
                x: 16
                y: 10
                xcText: "占位商品"
                xcFontSize: 13
                onCenter: false
            }

            XCCheckBox {
                id: placeholderEnabled
                x: 16
                y: 38
                text: "启用占位商品"
                onToggled: function(checked) {
                    if (root.uiPage)
                        root.uiPage.setPlaceholderEnabled(checked)
                }
            }

            ElementSelectionCompact {
                id: placeholderSelection
                x: 130
                y: 6
                width: Math.max(0, parent.width - x - 16)
                selectionId: "item"
                enabled: placeholderEnabled.checked
                opacity: enabled ? 1 : 0.52
                onElementSelected: function(filePath) {
                    if (root.uiPage)
                        root.uiPage.setPlaceholderElement(filePath)
                }
                onSelectionCleared: if (root.uiPage) root.uiPage.setPlaceholderElement("")
            }
        }
    }

    Flickable {
        id: nestedEditor
        visible: root.nestedPreview
        x: 1
        y: 49
        width: parent.width - 2
        height: Math.max(0, parent.height - y - 8)
        clip: true
        contentWidth: width
        contentHeight: height
        interactive: false

        Item {
            id: nestedContent
            width: nestedEditor.width
            height: nestedEditor.height

            XCText {
                x: 16
                y: 3
                width: 110
                xcText: root.selectedGroup ? root.selectedGroup.name : "嵌套组"
                xcFontSize: 13
                onCenter: false
                elide: Text.ElideRight
            }

            XCCheckBox {
                id: nestedEnabled
                x: 16
                y: 27
                text: "启用此嵌套"
                onToggled: function(checked) {
                    if (root.uiPage && root.uiPage.selectedNestedGroupId.length)
                        root.uiPage.setNestedGroupEnabled(
                                    root.uiPage.selectedNestedGroupId, checked)
                }
            }

            ElementSelectionCompact {
                id: nestedSelection
                x: 136
                y: 2
                width: Math.max(0, parent.width - x - 16)
                selectionId: "ui"
                enabled: !root.selectedGroupInputEnabled
                opacity: enabled ? 1 : 0.48
                onElementSelected: function(filePath) {
                    if (root.uiPage && root.uiPage.selectedNestedGroupId.length)
                        root.uiPage.setNestedGroupElement(
                                    root.uiPage.selectedNestedGroupId, filePath)
                }
                onSelectionCleared: {
                    if (root.uiPage && root.uiPage.selectedNestedGroupId.length)
                        root.uiPage.setNestedGroupElement(
                                    root.uiPage.selectedNestedGroupId, "")
                }
            }

            Rectangle {
                visible: root.selectedGroupInputEnabled
                x: nestedSelection.x
                y: nestedSelection.y
                width: nestedSelection.width
                height: nestedSelection.height
                radius: nestedSelection.radius
                color: Colors.changeA(Colors.card, 0.88)
                border.width: 1
                border.color: Colors.changeA(Colors.outline, 0.12)

                XCText {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    xcText: "此嵌套组已启用布局输入器"
                    xcFontSize: 11
                    boldFont: false
                    onCenter: true
                    textColor: Colors.banned
                    elide: Text.ElideRight
                }
            }

            ScoreboardFilter {
                id: nestedFilter
                x: 136
                y: 47
                width: Math.max(0, parent.width - x - 16)
                compact: true
                onFilterEdited: function(scoreboardName, targetName, scoreRange) {
                    if (root.uiPage && root.uiPage.selectedNestedGroupId.length)
                        root.uiPage.setNestedGroupFilter(
                                    root.uiPage.selectedNestedGroupId,
                                    scoreboardName, targetName, scoreRange)
                }
            }

            TextButton {
                x: 16
                y: 49
                width: 110
                height: 32
                radius: 8
                text: root.uiPage && root.uiPage.nestingDrawMode
                      ? "绘制完毕" : "开始绘制嵌套栏位"
                textSize: 12
                boldFont: false
                buttonColor: root.uiPage && root.uiPage.nestingDrawMode
                             ? Colors.changeA(Colors.border, 0.72)
                             : Colors.changeA(Colors.background, 0.42)
                firedColor: Colors.changeA(Colors.border, 0.84)
                pressedColor: Colors.changeA(Colors.border, 0.55)
                onClicked: {
                    if (root.uiPage)
                        root.uiPage.setNestingDrawMode(!root.uiPage.nestingDrawMode)
                }
            }
        }
    }

    Connections {
        target: root.uiPage

        function onLayoutDataChanged() { root.refresh() }
        function onSelectedNestedGroupIdChanged() {
            Qt.callLater(root.syncEditors)
            Qt.callLater(root.revealSelectedGroup)
        }
    }

    Component.onCompleted: refresh()
}
