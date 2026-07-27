pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Rectangle {
    id: root

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
    property bool writingState: false

    property bool selectionMode: false
    property string selectionType: ""
    property var draggedRecord: null
    property int draggedSourceIndex: -1
    property string dragTargetGroupKey: ""
    property int dragTargetSourceIndex: -1
    readonly property bool groupDropPreviewActive: draggedRecord
                                                  && dragTargetGroupKey.length > 0
                                                  && dragTargetGroupKey !== currentGroupKey

    readonly property bool supportedWorkspace: Global.current_element === "UI"
                                               || Global.current_element === "Item"
                                               || Global.current_element === "Cost"
                                               || Global.current_element === "Display"
    readonly property int columnCount: Math.max(1, Math.floor((itemGrid.width + 8) / 190))
    readonly property int rowCount: Math.max(1, Math.floor((itemGrid.height + 4) / 54))
    readonly property int pageSize: Math.max(1, columnCount * rowCount)
    readonly property int pageCount: Math.max(1, Math.ceil(filteredItemCount / pageSize))

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

    function emptyState() {
        return { "recent": [], "favorites": [], "groups": [] }
    }

    function cloneValue(value) {
        try {
            return JSON.parse(JSON.stringify(value))
        } catch (error) {
            return null
        }
    }

    function normalizeState(value) {
        var result = value && typeof value === "object" ? cloneValue(value) : null
        if (!result)
            result = emptyState()
        if (!Array.isArray(result.recent))
            result.recent = []
        if (!Array.isArray(result.favorites))
            result.favorites = []
        if (!Array.isArray(result.groups))
            result.groups = []
        for (var i = 0; i < result.groups.length; ++i) {
            if (!result.groups[i].id)
                result.groups[i].id = "group-" + i
            if (!result.groups[i].name)
                result.groups[i].name = "分组 " + (i + 1)
            if (!Array.isArray(result.groups[i].items))
                result.groups[i].items = []
        }
        return result
    }

    function loadState() {
        relayState = normalizeState(Global.elementRelayState(Global.project_location))
        currentGroupKey = "recent"
        currentPage = 0
        rebuildTabs()
        rebuildItems()
    }

    function persistState() {
        if (!Global.project_location.length)
            return
        writingState = true
        Global.saveElementRelayState(Global.project_location, relayState)
        writingState = false
    }

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

    function customGroupIndex(key) {
        if (key.indexOf("custom:") !== 0)
            return -1
        var id = key.substring(7)
        for (var i = 0; i < relayState.groups.length; ++i) {
            if (relayState.groups[i].id === id)
                return i
        }
        return -1
    }

    function rawItemsForGroup(key) {
        if (key === "recent")
            return relayState.recent
        if (key === "favorites")
            return relayState.favorites
        var index = customGroupIndex(key)
        return index >= 0 ? relayState.groups[index].items : []
    }

    function canonicalType(value) {
        switch (String(value || "").toLowerCase()) {
        case "ui": return "UI"
        case "item": return "Item"
        case "cost": return "Cost"
        case "display": return "Display"
        default: return ""
        }
    }

    function typeLabel(value) {
        switch (canonicalType(value)) {
        case "UI": return "界面"
        case "Item": return "商品"
        case "Cost": return "代价"
        case "Display": return "展示"
        default: return "元素"
        }
    }

    function normalizedRecord(elementType, filePath, elementName) {
        var parsed = Global.parseElementPath(filePath)
        if (!parsed)
            return null
        var type = canonicalType(elementType)
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
        var source = rawItemsForGroup(currentGroupKey)
        var result = []
        var requiredType = canonicalType(selectionType)
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

    function indexOfPath(items, path) {
        for (var i = 0; i < items.length; ++i) {
            if (Global.normalizeElementPath(items[i].path) === Global.normalizeElementPath(path))
                return i
        }
        return -1
    }

    function removePath(items, path) {
        var result = []
        for (var i = 0; i < items.length; ++i) {
            if (Global.normalizeElementPath(items[i].path) !== Global.normalizeElementPath(path))
                result.push(items[i])
        }
        return result
    }

    function addRecent(elementType, filePath, elementName) {
        var record = normalizedRecord(elementType, filePath, elementName)
        if (!record)
            return
        var recent = removePath(relayState.recent, record.path)
        recent.unshift(record)
        relayState.recent = recent.slice(0, 60)
        persistState()
        if (currentGroupKey === "recent")
            rebuildItems()
    }

    function isFavorite(filePath) {
        return indexOfPath(relayState.favorites, filePath) >= 0
    }

    function toggleFavorite(record) {
        var favorites = removePath(relayState.favorites, record.path)
        if (!isFavorite(record.path))
            favorites.unshift(cloneValue(record))
        relayState.favorites = favorites
        persistState()
        rebuildItems()
    }

    function addCustomGroup(groupName) {
        var name = String(groupName || "").trim()
        if (!name.length)
            return
        var id = "group-" + Date.now().toString(36)
        relayState.groups.push({ "id": id, "name": name, "items": [] })
        persistState()
        rebuildTabs()
        selectGroup("custom:" + id)
        newGroupEditor.visible = false
        newGroupField.text = ""
    }

    function moveRecordToGroup(record, targetKey) {
        if (!record)
            return
        if (targetKey === "recent") {
            addRecent(record.type, record.path, record.name)
            return
        }
        if (targetKey === "favorites") {
            if (!isFavorite(record.path)) {
                relayState.favorites.unshift(cloneValue(record))
                persistState()
            }
            return
        }

        var targetIndex = customGroupIndex(targetKey)
        if (targetIndex < 0)
            return
        var sourceIndex = customGroupIndex(currentGroupKey)
        if (sourceIndex >= 0 && sourceIndex !== targetIndex)
            relayState.groups[sourceIndex].items = removePath(relayState.groups[sourceIndex].items, record.path)
        relayState.groups[targetIndex].items = removePath(relayState.groups[targetIndex].items, record.path)
        relayState.groups[targetIndex].items.push(cloneValue(record))
        persistState()
        rebuildTabs()
        rebuildItems()
    }

    function reorderCurrentGroup(record, targetSourceIndex) {
        if (!record)
            return
        var items = rawItemsForGroup(currentGroupKey)
        var sourceIndex = indexOfPath(items, record.path)
        if (sourceIndex < 0 || targetSourceIndex < 0 || sourceIndex === targetSourceIndex)
            return
        var moved = items.splice(sourceIndex, 1)[0]
        if (sourceIndex < targetSourceIndex)
            targetSourceIndex -= 1
        items.splice(Math.max(0, Math.min(targetSourceIndex, items.length)), 0, moved)
        if (currentGroupKey === "recent")
            relayState.recent = items
        else if (currentGroupKey === "favorites")
            relayState.favorites = items
        else {
            var groupIndex = customGroupIndex(currentGroupKey)
            if (groupIndex >= 0)
                relayState.groups[groupIndex].items = items
        }
        persistState()
        rebuildItems()
    }

    function removeRecordEverywhere(filePath) {
        relayState.recent = removePath(relayState.recent, filePath)
        relayState.favorites = removePath(relayState.favorites, filePath)
        for (var i = 0; i < relayState.groups.length; ++i)
            relayState.groups[i].items = removePath(relayState.groups[i].items, filePath)
        persistState()
        rebuildItems()
    }

    function removeRecordFromCurrentGroup(filePath) {
        if (currentGroupKey === "recent")
            relayState.recent = removePath(relayState.recent, filePath)
        else if (currentGroupKey === "favorites")
            relayState.favorites = removePath(relayState.favorites, filePath)
        else {
            var groupIndex = customGroupIndex(currentGroupKey)
            if (groupIndex < 0)
                return
            relayState.groups[groupIndex].items = removePath(relayState.groups[groupIndex].items, filePath)
        }
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
            if (canonicalType(record.type) !== canonicalType(selectionType))
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
        selectionType = canonicalType(type)
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
            if (!selectionId.length || root.canonicalType(selectionId) === root.selectionType)
                root.endSelection()
        }
        function onElementSelectionFocusChanged(active, sceneRect) {
            if (!active)
                root.endSelection()
        }
    }

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
            xcFontSize: 11
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
                width: 42
                height: 28
                xcText: (root.currentPage + 1) + "/" + root.pageCount
                xcFontSize: 10
                boldFont: false
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
                    delegate: Rectangle {
                        id: tabDelegate
                        required property var modelData
                        readonly property bool selected: root.currentGroupKey === modelData.key
                        width: tabLabel.width + 22
                        height: 28
                        radius: 7
                        readonly property bool dropTarget: root.draggedRecord
                                                          && root.dragTargetGroupKey === modelData.key
                        color: dropTarget ? Colors.changeA(Colors.border, 0.32)
                                          : (selected ? Colors.changeA(Colors.border, 0.20)
                                        : (tabMouse.containsMouse ? Colors.changeA(Colors.fired, 0.46)
                                                                  : Colors.changeA(Colors.background, 0.22)))
                        border.width: 1
                        border.color: dropTarget ? Colors.changeA(Colors.border, 0.92)
                                               : (selected ? Colors.changeA(Colors.border, 0.56)
                                               : Colors.changeA(Colors.text, 0.08)
                                               )
                        scale: dropTarget ? 1.12 : 1
                        z: dropTarget ? 10 : 0
                        transformOrigin: Item.Center

                        Behavior on color { ColorAnimation { duration: 110 } }
                        Behavior on border.color { ColorAnimation { duration: 110 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        XCText {
                            id: tabLabel
                            anchors.centerIn: parent
                            xcText: tabDelegate.modelData.label
                            xcFontSize: 11
                            boldFont: false
                            textColor: tabDelegate.selected ? Colors.border : Colors.text
                        }
                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.selectGroup(tabDelegate.modelData.key)
                        }
                        DropArea {
                            anchors.fill: parent
                            keys: ["xcshop-element"]
                            onEntered: function(drag) {
                                if (root.draggedRecord && tabDelegate.modelData.key !== root.currentGroupKey) {
                                    root.setDragTarget(tabDelegate.modelData.key)
                                    drag.acceptProposedAction()
                                }
                            }
                            onExited: root.clearDragTarget(tabDelegate.modelData.key)
                            onDropped: function(drop) {
                                if (root.draggedRecord && tabDelegate.modelData.key !== root.currentGroupKey) {
                                    var record = root.cloneValue(root.draggedRecord)
                                    var targetKey = tabDelegate.modelData.key
                                    drop.acceptProposedAction()
                                    root.clearDragTarget()
                                    Qt.callLater(function() { root.moveRecordToGroup(record, targetKey) })
                                }
                            }
                        }
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
                xcText: "请选择" + root.typeLabel(root.selectionType) + "元素"
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

        delegate: Item {
            id: relayDelegate
            required property string path
            required property string name
            required property string elementType
            required property string relativePath
            required property int sourceIndex

            property var recordData: ({
                "path": path,
                "name": name,
                "type": elementType,
                "relativePath": relativePath
            })

            width: itemGrid.cellWidth
            height: itemGrid.cellHeight

            Rectangle {
                id: card
                property bool dragging: false
                property bool suppressClick: false
                readonly property bool reorderTarget: root.draggedRecord
                                                    && root.dragTargetGroupKey === root.currentGroupKey
                                                    && root.dragTargetSourceIndex === relayDelegate.sourceIndex
                                                    && root.draggedSourceIndex !== relayDelegate.sourceIndex
                x: 4
                y: 4
                width: relayDelegate.width - 8
                height: relayDelegate.height - 8
                radius: 9
                color: card.dragging ? Colors.changeA(Colors.pressed, 0.98)
                                     : (cardMouse.containsMouse ? Colors.changeA(Colors.fired, 0.62)
                                                               : Colors.changeA(Colors.background, 0.34))
                border.width: 1
                border.color: card.dragging ? Colors.changeA(Colors.border, 0.82)
                                            : Colors.changeA(Colors.text, 0.09)
                z: card.dragging ? 200 : 0
                scale: root.groupDropPreviewActive && card.dragging ? 0.72 : 1
                transformOrigin: Item.Center

                Drag.active: cardMouse.drag.active
                Drag.keys: ["xcshop-element"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2
                Drag.mimeData: ({ "text/plain": relayDelegate.path })

                Behavior on color { ColorAnimation { duration: 110 } }
                Behavior on border.color { ColorAnimation { duration: 110 } }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 30
                    radius: 7
                    color: Colors.changeA(Colors.border, 0.13)
                    border.width: 1
                    border.color: Colors.changeA(Colors.border, 0.34)
                    XCText {
                        anchors.centerIn: parent
                        xcText: root.typeLabel(relayDelegate.elementType)
                        xcFontSize: 10
                        boldFont: false
                        textColor: Colors.border
                    }
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
                        xcText: relayDelegate.name
                        xcFontSize: 12
                        onCenter: false
                    }
                    XCText {
                        width: parent.width
                        xcText: relayDelegate.relativePath
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
                    text: root.isFavorite(relayDelegate.path) ? "★" : "☆"
                    textSize: 17
                    textColor: root.isFavorite(relayDelegate.path) ? Colors.border : Colors.banned
                    buttonColor: Colors.transparent
                    firedColor: Colors.changeA(Colors.border, 0.16)
                    pressedColor: Colors.changeA(Colors.border, 0.28)
                    onClicked: root.toggleFavorite(relayDelegate.recordData)
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
                    onClicked: root.removeRecordFromCurrentGroup(relayDelegate.path)
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
                            root.draggedRecord = relayDelegate.recordData
                            root.draggedSourceIndex = relayDelegate.sourceIndex
                            SignalBus.draggedElementPath = relayDelegate.path
                            SignalBus.elementDragStateChanged(true)
                        }
                    }
                    onReleased: {
                        if (card.dragging) {
                            card.Drag.drop()
                            SignalBus.elementDragStateChanged(false)
                            root.draggedRecord = null
                            card.dragging = false
                            card.x = 4
                            card.y = 4
                            Qt.callLater(function() {
                                SignalBus.draggedElementPath = ""
                                root.draggedSourceIndex = -1
                                root.clearDragTarget()
                                card.suppressClick = false
                            })
                        }
                    }
                    onCanceled: {
                        if (card.dragging)
                            SignalBus.elementDragStateChanged(false)
                        root.draggedRecord = null
                        root.draggedSourceIndex = -1
                        root.clearDragTarget()
                        SignalBus.draggedElementPath = ""
                        card.dragging = false
                        card.x = 4
                        card.y = 4
                        card.suppressClick = false
                    }
                    onClicked: {
                        if (!card.suppressClick)
                            root.useRecord(relayDelegate.recordData)
                    }
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["xcshop-element"]
                    onEntered: function(drag) {
                        if (root.draggedRecord && root.draggedSourceIndex !== relayDelegate.sourceIndex) {
                            root.setDragTarget(root.currentGroupKey, relayDelegate.sourceIndex)
                            drag.acceptProposedAction()
                        }
                    }
                    onExited: root.clearDragTarget(root.currentGroupKey, relayDelegate.sourceIndex)
                    onDropped: function(drop) {
                        if (root.draggedRecord) {
                            var record = root.cloneValue(root.draggedRecord)
                            var targetIndex = relayDelegate.sourceIndex
                            drop.acceptProposedAction()
                            root.clearDragTarget()
                            Qt.callLater(function() { root.reorderCurrentGroup(record, targetIndex) })
                        }
                    }
                }
            }

            Rectangle {
                id: insertionMarker
                readonly property bool atRowStart: relayDelegate.sourceIndex % root.columnCount === 0
                visible: card.reorderTarget
                z: 300
                x: atRowStart ? 4 : 0
                y: atRowStart ? 0 : 6
                width: atRowStart ? relayDelegate.width - 8 : 3
                height: atRowStart ? 3 : relayDelegate.height - 12
                radius: 2
                color: Colors.changeA(Colors.border, 0.96)

                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }

        XCText {
            visible: pageModel.count === 0
            anchors.centerIn: parent
            xcText: root.selectionMode
                    ? "此分组中暂无可用的" + root.typeLabel(root.selectionType) + "元素"
                    : "当前分组还没有元素"
            xcFontSize: 12
            boldFont: false
            textColor: Colors.banned
        }
    }
}
