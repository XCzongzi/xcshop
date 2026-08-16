pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs
import xcshop

Item {
    id: root

    readonly property string itemsRootPath: APP_DIRPATH + "/../assets/minecraft/items"
    readonly property string vanillaItemsPath: itemsRootPath + "/items.json"
    readonly property string customItemsPath: itemsRootPath + "/custom-items.json"

    property var vanillaItems: []
    property var customItems: []
    property var itemMappings: []
    property var filteredItems: []
    property string itemSearch: ""
    property int sourceFilter: 0 // 0: 全部，1: 原版，2: 自定义
    property string formError: ""
    property string pendingRemovalId: ""
    readonly property int listContentHeight: Math.max(300, root.height - header.height - addMappingBar.height - 28)

    XCFile { id: xcFile }

    function fileUrl(path) {
        if (!path || !path.length)
            return ""
        if (path.indexOf("://") >= 0 || path.indexOf("qrc:") === 0)
            return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    function itemName(itemId) {
        var separator = itemId.indexOf(":")
        return separator >= 0 ? itemId.substring(separator + 1) : itemId
    }

    function itemNamespace(itemId) {
        var separator = itemId.indexOf(":")
        return separator >= 0 ? itemId.substring(0, separator) : "minecraft"
    }

    function itemIconPath(itemId) {
        return itemsRootPath + "/assets/" + itemNamespace(itemId) + "/" + itemName(itemId) + ".png"
    }

    function hasMappedTexture(itemId) {
        return xcFile.exists(itemIconPath(itemId))
    }

    function loadItemMappings() {
        var rawVanilla = xcFile.read(vanillaItemsPath)
        var rawCustom = xcFile.read(customItemsPath)
        try { vanillaItems = rawVanilla.length ? JSON.parse(rawVanilla) : [] }
        catch (error) { vanillaItems = [] }
        try { customItems = rawCustom.length ? JSON.parse(rawCustom) : [] }
        catch (error) { customItems = [] }

        if (!Array.isArray(vanillaItems)) vanillaItems = []
        if (!Array.isArray(customItems)) customItems = []

        var mappings = []
        for (var vanillaIndex = 0; vanillaIndex < vanillaItems.length; ++vanillaIndex) {
            var vanilla = vanillaItems[vanillaIndex]
            if (vanilla && vanilla.name && vanilla.name !== "minecraft:air")
                mappings.push({ itemId: vanilla.name, numericId: vanilla.id, builtIn: true })
        }
        for (var customIndex = 0; customIndex < customItems.length; ++customIndex) {
            var custom = customItems[customIndex]
            if (custom && custom.itemId)
                mappings.push({ itemId: custom.itemId, numericId: "", builtIn: false })
        }
        itemMappings = mappings
        filterItems()
    }

    function filterItems() {
        var keyword = itemSearch.trim().toLowerCase()
        var matches = []
        for (var index = 0; index < itemMappings.length; ++index) {
            var entry = itemMappings[index]
            if ((sourceFilter === 1 && !entry.builtIn) || (sourceFilter === 2 && entry.builtIn))
                continue
            if (!keyword.length) {
                matches.push({ entry: entry, score: 0 })
                continue
            }

            var fullId = entry.itemId.toLowerCase()
            var localId = itemName(fullId)
            var score = -1
            if (fullId === keyword)
                score = 0
            else if (localId === keyword)
                score = 1
            else if (fullId.indexOf(keyword) === 0)
                score = 2
            else if (localId.indexOf(keyword) === 0)
                score = 3
            else {
                var words = localId.split(/[_./-]+/)
                for (var wordIndex = 0; wordIndex < words.length; ++wordIndex) {
                    if (words[wordIndex].indexOf(keyword) === 0) {
                        score = 4
                        break
                    }
                }
                if (score < 0) {
                    var fullPosition = fullId.indexOf(keyword)
                    var localPosition = localId.indexOf(keyword)
                    if (localPosition >= 0)
                        score = 20 + localPosition
                    else if (fullPosition >= 0)
                        score = 100 + fullPosition
                }
            }
            if (score >= 0)
                matches.push({ entry: entry, score: score })
        }
        matches.sort(function(left, right) {
            if (left.score !== right.score)
                return left.score - right.score
            return left.entry.itemId.localeCompare(right.entry.itemId)
        })
        filteredItems = matches.map(function(match) { return match.entry })
    }

    function customItemExists(itemId) {
        for (var index = 0; index < itemMappings.length; ++index)
            if (itemMappings[index].itemId === itemId)
                return true
        return false
    }

    function saveCustomItem() {
        var itemId = customIdInput.text.trim().toLowerCase()
        var iconPath = customIconInput.text.trim()
        formError = ""
        if (!/^[a-z0-9_.-]+:[a-z0-9_./-]+$/.test(itemId)) {
            formError = "请使用命名空间 ID，例如 examplemod:machine。"
            return
        }
        if (!iconPath.length) {
            formError = "请为自定义物品选择图标。"
            return
        }
        if (customItemExists(itemId)) {
            formError = "该物品 ID 已存在，不能覆盖原版或重复添加。"
            return
        }

        var destinationPath = itemIconPath(itemId)
        if (!xcFile.copy(iconPath, destinationPath)) {
            formError = "无法复制图标到物品资源目录，请确认源文件可访问。"
            return
        }

        var nextItems = customItems.slice()
        nextItems.push({ itemId: itemId })
        if (!xcFile.write(customItemsPath, JSON.stringify(nextItems))) {
            xcFile.remove_file(destinationPath)
            formError = "无法写入 custom-items.json，请检查资源目录权限。"
            return
        }
        customIdInput.text = ""
        customIconInput.text = ""
        loadItemMappings()
    }

    function removeCustomItem(itemId) {
        var nextItems = []
        for (var index = 0; index < customItems.length; ++index)
            if (customItems[index].itemId !== itemId)
                nextItems.push(customItems[index])
        if (xcFile.write(customItemsPath, JSON.stringify(nextItems))) {
            xcFile.remove_file(itemIconPath(itemId))
            loadItemMappings()
        }
    }

    Component.onCompleted: loadItemMappings()

    XCFileDialog {
        id: imageFileDialog
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp)", "All files (*)"]
        onAccepted: customIconInput.text = selectedFile.toString()
    }

    Column {
        anchors.fill: parent
        spacing: 12

        SettingsPageHeader {
            id: header
            width: parent.width
            title: "物品映射表"
            subtitle: "读取当前 Minecraft 原版物品清单；图标按命名空间存储在 assets/minecraft/items/assets/<namespace>/。"
        }

        ContentBar {
            id: addMappingBar
            width: parent.width
            expanded: true
            title: "添加自定义物品"
            subtitle: "自定义条目可删除，原版条目始终保持只读。"
            contentHeight: addFields.y + addFields.height + (root.formError.length ? 24 : 0) + 16

            Row {
                id: addFields
                x: 16
                y: 70
                width: parent.width - 32
                spacing: 10

                Column {
                    width: Math.max(190, parent.width * 0.34)
                    spacing: 5
                    XCText { xcText: "物品 ID"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    XCTextField { id: customIdInput; width: parent.width; placeholderText: "examplemod:machine" }
                }
                Column {
                    width: Math.max(220, parent.width - parent.spacing * 2 - parent.children[0].width - parent.children[2].width)
                    spacing: 5
                    XCText { xcText: "物品图标"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    XCTextField { id: customIconInput; width: parent.width; placeholderText: "选择本地 PNG、JPG、WebP 或 BMP 图像" }
                }
                Column {
                    width: 126
                    spacing: 5
                    XCText { xcText: "操作"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    Row {
                        spacing: 5
                        TextButton { text: "选图标"; height: 32; radius: 7; textSize: 12; widthBorderSize: 8; buttonColor: Colors.pressed; onClicked: imageFileDialog.openXC(false, "customItemIcon") }
                        TextButton { text: "添加"; height: 32; radius: 7; textSize: 12; widthBorderSize: 8; buttonColor: Colors.changeA(Colors.border, 0.72); textColor: "#1b1b1b"; onClicked: root.saveCustomItem() }
                    }
                }
            }

            XCText {
                visible: root.formError.length > 0
                x: 16
                y: addFields.y + addFields.height + 5
                width: parent.width - 32
                xcText: root.formError
                onCenter: false
                xcFontSize: 12
                boldFont: false
                textColor: Colors.error
            }
        }

        ContentBar {
            id: mappingListBar
            width: parent.width
            expanded: true
            title: "当前的物品映射表"
            subtitle: "共 " + root.itemMappings.length + " 项，当前显示 " + root.filteredItems.length + " 项。"
            contentHeight: root.listContentHeight

            XCTextField {
                id: itemSearchField
                x: 16
                y: 70
                width: Math.max(180, parent.width - 16 - sourceSelector.width - 26)
                placeholderText: "按物品 ID 搜索，例如 minecraft:diamond"
                onTextChanged: {
                    root.itemSearch = text
                    root.filterItems()
                }
            }

            ComboBox {
                id: sourceSelector
                anchors.right: parent.right
                anchors.rightMargin: 16
                y: 70
                per_width: 108
                per_height: 32
                options: ["全部", "原版", "自定义"]
                onClicked: {
                    root.sourceFilter = selected
                    root.filterItems()
                }
            }

            Rectangle {
                x: 16
                y: 114
                width: parent.width - 32
                height: 1
                color: Colors.changeA(Colors.text, 0.10)
            }

            Item {
                id: tableHeader
                x: 16
                y: 122
                width: parent.width - 32
                height: 24
                XCText { x: 8; width: 48; xcText: "图标"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { x: 68; width: parent.width - 340; xcText: "物品 ID"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { x: parent.width - 260; width: 62; xcText: "来源"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { x: parent.width - 180; width: 94; xcText: "映射状态"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { x: parent.width - 78; width: 70; xcText: "操作"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
            }

            ListView {
                id: itemTable
                x: 16
                y: 148
                width: parent.width - 32
                height: parent.height - y - 12
                clip: true
                spacing: 3
                model: root.filteredItems

                delegate: Rectangle {
                    id: itemDelegate
                    required property var modelData
                    width: ListView.view.width
                    height: 42
                    radius: 7
                    color: rowMouse.containsMouse ? Colors.changeA(Colors.foreground, 0.78) : Colors.changeA(Colors.background, 0.22)
                    border.width: 1
                    border.color: Colors.changeA(Colors.text, rowMouse.containsMouse ? 0.11 : 0.05)

                    property string iconSource: root.fileUrl(root.itemIconPath(itemDelegate.modelData.itemId))
                    property bool textureMapped: root.hasMappedTexture(itemDelegate.modelData.itemId)

                    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true }

                    Rectangle {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 5
                        visible: itemDelegate.iconSource.length > 0
                        color: Colors.changeA(Colors.foreground, 0.82)
                        Image {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: itemDelegate.iconSource
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            mipmap: false
                            asynchronous: true
                            onStatusChanged: {
                                if (status === Image.Error)
                                    itemDelegate.iconSource = ""
                            }
                        }
                    }

                    XCText {
                        x: 68
                        width: parent.width - 340
                        xcText: itemDelegate.modelData.itemId
                        onCenter: false
                        xcFontSize: 13
                        boldFont: false
                        elide: Text.ElideMiddle
                    }
                    XCText {
                        x: parent.width - 260
                        width: 62
                        xcText: itemDelegate.modelData.builtIn ? "原版" : "自定义"
                        onCenter: false
                        xcFontSize: 12
                        boldFont: false
                        textColor: itemDelegate.modelData.builtIn ? Colors.banned : Colors.border
                    }
                    XCText {
                        x: parent.width - 180
                        width: 94
                        xcText: itemDelegate.textureMapped ? "已匹配至贴图" : "未匹配至贴图"
                        onCenter: false
                        xcFontSize: 11
                        boldFont: false
                        textColor: itemDelegate.textureMapped ? Colors.border : Colors.banned
                    }
                    TextButton {
                        visible: !itemDelegate.modelData.builtIn
                        x: parent.width - width - 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "删除"
                        height: 26
                        radius: 5
                        textSize: 11
                        widthBorderSize: 8
                        buttonColor: Colors.transparent
                        firedColor: Colors.changeA(Colors.error, 0.22)
                        pressedColor: Colors.changeA(Colors.error, 0.42)
                        onClicked: {
                            root.pendingRemovalId = itemDelegate.modelData.itemId
                            removeNotice.show()
                        }
                    }
                    XCText {
                        visible: itemDelegate.modelData.builtIn
                        x: parent.width - 78
                        width: 70
                        xcText: "只读"
                        onCenter: false
                        xcFontSize: 11
                        boldFont: false
                        textColor: Colors.banned
                    }
                }
            }

            Rectangle {
                id: itemTableScrollBar
                anchors.top: itemTable.top
                anchors.bottom: itemTable.bottom
                anchors.right: itemTable.right
                width: 7
                radius: width / 2
                visible: itemTable.contentHeight > itemTable.height
                color: Colors.changeA(Colors.background, 0.30)

                readonly property real maxContentY: Math.max(0, itemTable.contentHeight - itemTable.height)
                readonly property real maxThumbY: Math.max(0, height - scrollThumb.height)

                Rectangle {
                    id: scrollThumb
                    width: parent.width
                    height: Math.max(34, parent.height * itemTable.height / Math.max(itemTable.height, itemTable.contentHeight))
                    y: itemTableScrollBar.maxContentY > 0
                       ? Math.max(0, Math.min(itemTableScrollBar.maxThumbY,
                                              itemTable.contentY / itemTableScrollBar.maxContentY * itemTableScrollBar.maxThumbY))
                       : 0
                    radius: width / 2
                    color: scrollHandle.containsMouse || scrollHandle.pressed
                           ? Colors.changeA(Colors.border, 0.92)
                           : Colors.changeA(Colors.banned, 0.62)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: scrollHandle
                        anchors.fill: parent
                        hoverEnabled: true
                        property real previousY: 0
                        onPressed: previousY = mouseY
                        onPositionChanged: {
                            if (!pressed || itemTableScrollBar.maxThumbY <= 0)
                                return
                            var targetY = Math.max(0, Math.min(itemTableScrollBar.maxThumbY,
                                                               scrollThumb.y + mouseY - previousY))
                            itemTable.contentY = targetY / itemTableScrollBar.maxThumbY * itemTableScrollBar.maxContentY
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: function(mouse) {
                        if (itemTableScrollBar.maxThumbY <= 0)
                            return
                        var targetY = Math.max(0, Math.min(itemTableScrollBar.maxThumbY, mouse.y - scrollThumb.height / 2))
                        itemTable.contentY = targetY / itemTableScrollBar.maxThumbY * itemTableScrollBar.maxContentY
                    }
                }
            }
        }
    }

    NoticeBoard {
        id: removeNotice
        anchors.fill: parent
        z: 20
        title: "删除自定义物品"
        content: "确定删除 “" + root.pendingRemovalId + "” 吗？此操作会更新 custom-items.json。"
        doubleBtn: true
        onCloseBtnClicked: function(type) {
            if (type === 1 && root.pendingRemovalId.length)
                root.removeCustomItem(root.pendingRemovalId)
            root.pendingRemovalId = ""
        }
    }
}
