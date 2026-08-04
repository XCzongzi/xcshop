pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import "../../js/ElementRelayState.js" as RelayState

Rectangle {
    id: root

    // ===== 容器配置与持久化状态 =====
    property bool workspaceActive: false
    property int minPanelHeight: 126
    property int maxPanelHeight: 420
    property int panelHeight: Global.elementRelayHeight
    property bool resizing: false

    property var relayState: ({ "recent": [], "favorites": [], "groups": [] })
    property var tabs: []
    property string currentGroupKey: "recent"
    property int currentPage: 0
    property int filteredItemCount: 0
    // ===== 瞬时交互状态 =====
    // 拖放与选择都是短生命周期的界面状态，不写入中转区状态文件。
    property bool selectionMode: false
    property string selectionType: ""
    property var draggedRecord: null
    property int draggedSourceIndex: -1
    property string dragTargetGroupKey: ""
    property int dragTargetSourceIndex: -1
    readonly property bool groupDropPreviewActive: draggedRecord
                                                  && dragTargetGroupKey.length > 0
                                                  && dragTargetGroupKey !== currentGroupKey

    // ===== 派生展示状态 =====
    readonly property bool supportedWorkspace: Global.current_element === "UI"
                                               || Global.current_element === "Item"
                                               || Global.current_element === "Cost"
                                               || Global.current_element === "Display"
    readonly property int columnCount: Math.max(1, Math.floor((itemGrid.width + 8) / 190))
    readonly property int rowCount: Math.max(1, Math.floor((itemGrid.height + 4) / 54))
    readonly property int pageSize: Math.max(1, columnCount * rowCount)
    readonly property int pageCount: Math.max(1, Math.ceil(filteredItemCount / pageSize))

    // ===== 对外通知 =====
    signal invalidElement(string filePath)
    signal elementActivated(string filePath)

    visible: workspaceActive && supportedWorkspace && Global.project_location.length > 0
    height: visible ? Math.max(minPanelHeight, Math.min(maxPanelHeight, panelHeight)) : 0
    color: Colors.changeA(Colors.foreground, 0.98)
    border.width: 1
    border.color: selectionMode ? Colors.changeA(Colors.border, 0.82)
                                : Colors.changeA(Colors.text, 0.12)
    clip: false

    Behavior on border.color { ColorAnimation { duration: 160 } }

    XCFile { id: relayFile }

    ListModel { id: pageModel }

    // ===== 状态加载与持久化 =====
    function loadState() {
        relayState = RelayState.normalizeState(Global.elementRelayState(Global.project_location))
        currentGroupKey = "recent"
        currentPage = 0
        rebuildTabs()
        rebuildItems()
    }

    function persistState() {
        if (!Global.project_location.length)
            return
        Global.saveElementRelayState(Global.project_location, relayState)
    }

    // ===== 分组与展示数据 =====
    function rebuildTabs() {
        var nextTabs = [
            { "key": "recent", "label": "最近" },
            { "key": "favorites", "label": "收藏" }
        ]
        for (var i = 0; i < relayState.groups.length; ++i) {
            nextTabs.push({
                "key": "custom:" + relayState.groups[i].id,
                "label": relayState.groups[i].name
            })
        }
        tabs = nextTabs
    }

    function normalizedRecord(elementType, filePath, elementName) {
        var parsed = Global.parseElementPath(filePath)
        if (!parsed)
            return null
        var type = RelayState.canonicalType(elementType)
        if (!type.length)
            type = parsed.type
        if (type !== parsed.type)
            return null
        return {
            "path": parsed.path,
            "type": type,
            "name": elementName && elementName.length ? elementName : parsed.name,
            "relativePath": parsed.relativePath
        }
    }

    function filteredItems() {
        var source = RelayState.itemsForGroup(relayState, currentGroupKey)
        var result = []
        var requiredType = RelayState.canonicalType(selectionType)
        for (var i = 0; i < source.length; ++i) {
            var record = normalizedRecord(source[i].type, source[i].path, source[i].name)
            if (!record)
                continue
            if (!selectionMode || record.type === requiredType) {
                record.sourceIndex = i
                result.push(record)
            }
        }
        return result
    }

    function rebuildItems() {
        var items = filteredItems()
        filteredItemCount = items.length
        currentPage = Math.max(0, Math.min(currentPage, Math.max(0, Math.ceil(items.length / pageSize) - 1)))
        pageModel.clear()
        var start = currentPage * pageSize
        var end = Math.min(items.length, start + pageSize)
        for (var i = start; i < end; ++i) {
            pageModel.append({
                "path": items[i].path,
                "name": items[i].name,
                "elementType": items[i].type,
                "relativePath": items[i].relativePath,
                "sourceIndex": items[i].sourceIndex
            })
        }
    }

    function selectGroup(key) {
        currentGroupKey = key
        currentPage = 0
        rebuildItems()
    }

    // ===== 元素集合变更 =====
    function addRecent(elementType, filePath, elementName) {
        var record = normalizedRecord(elementType, filePath, elementName)
        if (!record)
            return
        RelayState.addRecent(relayState, record, Global.normalizeElementPath)
        persistState()
        if (currentGroupKey === "recent")
            rebuildItems()
    }

    function isFavorite(filePath) {
        return RelayState.indexOfPath(relayState.favorites, filePath,
                                      Global.normalizeElementPath) >= 0
    }

    function toggleFavorite(record) {
        RelayState.toggleFavorite(relayState, record, Global.normalizeElementPath)
        persistState()
        rebuildItems()
    }

    function addCustomGroup(groupName) {
        var name = String(groupName || "").trim()
        if (!name.length)
            return
        var id = "group-" + Date.now().toString(36)
        RelayState.addCustomGroup(relayState, name, id)
        persistState()
        rebuildTabs()
        selectGroup("custom:" + id)
        newGroupEditor.visible = false
        newGroupField.text = ""
    }

    function moveRecordToGroup(record, targetKey) {
        if (!record)
            return
        RelayState.moveRecordToGroup(relayState, currentGroupKey, record, targetKey,
                                     Global.normalizeElementPath)
        persistState()
        rebuildTabs()
        rebuildItems()
    }

    function reorderCurrentGroup(record, targetSourceIndex) {
        if (!record)
            return
        if (!RelayState.reorderGroup(relayState, currentGroupKey, record, targetSourceIndex,
                                     Global.normalizeElementPath))
            return
        persistState()
        rebuildItems()
    }

    function removeRecordEverywhere(filePath) {
        RelayState.removeRecordEverywhere(relayState, filePath, Global.normalizeElementPath)
        persistState()
        rebuildItems()
    }

    function removeRecordFromCurrentGroup(filePath) {
        if (!RelayState.removeRecordFromGroup(relayState, currentGroupKey, filePath,
                                              Global.normalizeElementPath))
            return
        persistState()
        rebuildItems()
    }

    function setDragTarget(groupKey, sourceIndex) {
        if (!draggedRecord)
            return
        dragTargetGroupKey = groupKey || ""
        dragTargetSourceIndex = sourceIndex === undefined ? -1 : sourceIndex
    }

    function clearDragTarget(groupKey, sourceIndex) {
        if (groupKey !== undefined && dragTargetGroupKey !== groupKey)
            return
        if (sourceIndex !== undefined && dragTargetSourceIndex !== sourceIndex)
            return
        dragTargetGroupKey = ""
        dragTargetSourceIndex = -1
    }

    function useRecord(record) {
        if (!record)
            return
        if (!relayFile.exists(record.path)) {
            removeRecordEverywhere(record.path)
            invalidElement(record.path)
            return
        }
        if (selectionMode) {
            if (RelayState.canonicalType(record.type) !== RelayState.canonicalType(selectionType))
                return
            SignalBus.elementSelectionResolved(record.path)
            selectionMode = false
            selectionType = ""
            rebuildItems()
            return
        }
        elementActivated(record.path)
    }

    function beginSelection(type) {
        newGroupEditor.visible = false
        newGroupField.text = ""
        selectionMode = true
        selectionType = RelayState.canonicalType(type)
        currentPage = 0
        rebuildItems()
    }

    function endSelection() {
        if (!selectionMode)
            return
        selectionMode = false
        selectionType = ""
        rebuildItems()
    }

    // ===== 生命周期与全局事件桥接 =====
    onPageSizeChanged: Qt.callLater(rebuildItems)
    onMaxPanelHeightChanged: panelHeight = Math.min(panelHeight, maxPanelHeight)
    onVisibleChanged: {
        if (visible)
            Qt.callLater(loadState)
    }

    Component.onCompleted: Qt.callLater(loadState)

    Connections {
        target: Global
        function onProject_locationChanged() { root.loadState() }
    }

    Connections {
        target: SignalBus
        function onElementOpened(elementType, filePath, elementName) {
            root.addRecent(elementType, filePath, elementName)
        }
        function onElementSelectionRequested(selectionId) {
            root.beginSelection(selectionId)
        }
        function onElementSelectionCancelled(selectionId) {
            if (!selectionId.length || RelayState.canonicalType(selectionId) === root.selectionType)
                root.endSelection()
        }
        function onElementSelectionFocusChanged(active, sceneRect) {
            if (!active)
                root.endSelection()
        }
    }

    //边框
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 5
        color: resizeArea.containsMouse || root.resizing ? Colors.changeA(Colors.border, 0.62)
                                                       : Colors.changeA(Colors.text, 0.08)

        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: resizeArea
            anchors.fill: parent
            anchors.topMargin: -3
            anchors.bottomMargin: -3
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
            property real pressSceneY: 0
            property int pressHeight: 0
            onPressed: function(mouse) {
                root.resizing = true
                pressSceneY = mapToItem(root.parent, mouse.x, mouse.y).y
                pressHeight = root.panelHeight
            }
            onPositionChanged: function(mouse) {
                if (!pressed)
                    return
                var currentSceneY = mapToItem(root.parent, mouse.x, mouse.y).y
                root.panelHeight = Math.max(root.minPanelHeight,
                                            Math.min(root.maxPanelHeight,
                                                     pressHeight + pressSceneY - currentSceneY))
            }
            onReleased: {
                root.resizing = false
                Global.saveElementRelayHeight(root.panelHeight)
            }
            onCanceled: root.resizing = false
        }
    }

    //顶栏
    Item {
        id: header
        z: root.groupDropPreviewActive ? 500 : 2
        x: 10
        y: 7
        width: parent.width - 20
        height: 34

        XCText {
            id: relayTitle
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 70
            xcText: "元素中转区"
            xcFontSize: 14
            boldFont: false
            onCenter: false
            textColor: root.selectionMode ? Colors.border : Colors.text
        }

        Row {
            id: pager
            anchors.left: relayTitle.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            TextButton {
                width: 28
                height: 28
                radius: 7
                text: "‹"
                textSize: 20
                enabled: root.currentPage > 0
                buttonColor: Colors.changeA(Colors.background, 0.26)
                onClicked: { root.currentPage -= 1; root.rebuildItems() }
            }
            XCText {
                xcText: (root.currentPage + 1) + "/" + root.pageCount
                xcFontSize: 16
                boldFont: false
                onCenter: false
                onVCenter: true
                textColor: Colors.banned
            }
            TextButton {
                width: 28
                height: 28
                radius: 7
                text: "›"
                textSize: 20
                enabled: root.currentPage + 1 < root.pageCount
                buttonColor: Colors.changeA(Colors.background, 0.26)
                onClicked: { root.currentPage += 1; root.rebuildItems() }
            }
        }

        Flickable {
            id: tabScroller
            anchors.left: pager.right
            anchors.leftMargin: 10
            anchors.right: root.selectionMode ? selectionHint.left : addGroupButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 34
            contentWidth: tabRow.width
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: tabRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: root.tabs
                    delegate: RelayTabCard{
                        relayBar: root
                    }
                }
            }
        }

        TextButton {
            id: addGroupButton
            visible: !root.selectionMode
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 28
            radius: 7
            text: "+"
            textSize: 19
            buttonColor: Colors.changeA(Colors.background, 0.28)
            firedColor: Colors.changeA(Colors.fired, 0.64)
            onClicked: {
                newGroupEditor.visible = true
                newGroupField.forceActiveFocus()
            }
        }

        Rectangle {
            id: selectionHint
            visible: root.selectionMode
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: selectionHintText.width + 22
            height: 28
            radius: 14
            color: Colors.changeA(Colors.border, 0.16)
            border.width: 1
            border.color: Colors.changeA(Colors.border, 0.52)
            XCText {
                id: selectionHintText
                anchors.centerIn: parent
                xcText: "请选择" + RelayState.typeLabel(root.selectionType) + "元素"
                xcFontSize: 11
                boldFont: false
                textColor: Colors.border
            }
        }

        Rectangle {
            id: newGroupEditor
            visible: false
            z: 20
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 224
            height: 34
            radius: 8
            color: Colors.foreground
            border.width: 1
            border.color: Colors.changeA(Colors.border, 0.64)

            XCTextField {
                id: newGroupField
                x: 4
                y: 3
                width: parent.width - 72
                height: 28
                font.pixelSize: 12
                placeholderText: "新分组名称"
                onAccepted: root.addCustomGroup(text)
            }
            TextButton {
                x: parent.width - 64
                y: 3
                width: 28
                height: 28
                radius: 6
                text: "✓"
                onClicked: root.addCustomGroup(newGroupField.text)
            }
            TextButton {
                x: parent.width - 32
                y: 3
                width: 28
                height: 28
                radius: 6
                text: "×"
                onClicked: { newGroupEditor.visible = false; newGroupField.text = "" }
            }
        }
    }

    //元素卡片网格与拖放
    GridView {
        id: itemGrid
        x: 8
        y: 43
        width: parent.width - 16
        height: parent.height - y - 5
        cellWidth: width / root.columnCount
        cellHeight: 54
        interactive: false
        clip: false
        model: pageModel

        delegate: ElementCard{
            relayBar: root
            width: itemGrid.cellWidth
            height: itemGrid.cellHeight
        }


        XCText {
            visible: pageModel.count === 0
            anchors.centerIn: parent
            xcText: root.selectionMode
                    ? "此分组中暂无可用的" + RelayState.typeLabel(root.selectionType) + "元素"
                    : "当前分组还没有元素"
            xcFontSize: 12
            boldFont: false
            textColor: Colors.banned
        }
    }
}
