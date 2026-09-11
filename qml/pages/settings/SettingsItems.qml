pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs
import xcshop
import "qrc:/assets/js/request.js" as XHR

Item {
    id: root

    readonly property string itemsRootPath: APP_DIRPATH + "/assets/minecraft/items"
    readonly property string vanillaItemsPath: itemsRootPath + "/items.json"
    readonly property string customItemsPath: itemsRootPath + "/custom-items.json"
    readonly property string versionMetadataPath: itemsRootPath + "/version.json"

    property var vanillaItems: []
    property var customItems: []
    property var itemMappings: []
    property var filteredItems: []
    property string itemSearch: ""
    property int iconRevision: 0
    property string gameVersion: "未记录"
    property int sourceFilter: 0 // 0: 全部，1: 原版，2: 自定义
    property string formError: ""
    property bool mappingDownloadInProgress: false
    property bool mappingDataReady: false
    property bool mappingVersionReady: false
    property bool mappingDownloadFailed: false
    property string downloadedMappingData: ""
    property string downloadedMappingVersion: ""
    property string mappingDownloadSource: ""
    property string mappingDownloadStatus: ""
    property var historicalMappingVersions: []
    property bool historicalVersionsLoading: false
    property bool historicalVersionsLoaded: false
    property string historicalVersionsStatus: ""
    property string importStatus: ""
    property int importProgress: 0
    property string pendingImportMessage: ""
    // Keep the mapping table useful even when the settings window is made small.
    // The surrounding Flickable exposes the rest of the page instead of shrinking
    // the table until it is no longer usable.
    readonly property int listContentHeight: Math.max(400, root.height - header.height - importBar.height - addMappingBar.height - 40)

    XCFile { id: xcFile }
    MinecraftAssetImporter { id: minecraftImporter }

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
        return Global.getItemTexturePath(itemId)
    }

    function hasMappedTexture(itemId) {
        return xcFile.exists(itemIconPath(itemId))
    }

    function loadGameVersion() {
        gameVersion = "未记录"
        var rawVersion = xcFile.read(versionMetadataPath)
        try {
            var metadata = rawVersion.length ? JSON.parse(rawVersion) : null
            if (metadata && typeof metadata.gameVersion === "string" && metadata.gameVersion.length)
                gameVersion = metadata.gameVersion
        } catch (error) {
        }
    }

    function validItemMappings(content) {
        try {
            var mappings = JSON.parse(content)
            if (!Array.isArray(mappings) || !mappings.length)
                return false
            for (var index = 0; index < mappings.length; ++index) {
                var item = mappings[index]
                if (!item || typeof item.name !== "string" || !item.name.length
                        || typeof item.id !== "number")
                    return false
            }
            return true
        } catch (error) {
            return false
        }
    }

    function finishMappingDownload() {
        if (!mappingDataReady || !mappingVersionReady)
            return

        mappingDownloadInProgress = false
        if (mappingDownloadFailed) {
            mappingDownloadStatus = "下载失败，当前映射表未被修改。"
            return
        }
        if (!xcFile.write(vanillaItemsPath, downloadedMappingData)) {
            mappingDownloadStatus = "无法写入 items.json，请检查资源目录权限。"
            return
        }
        var metadata = { gameVersion: downloadedMappingVersion,
                         source: mappingDownloadSource }
        if (!xcFile.write(versionMetadataPath, JSON.stringify(metadata))) {
            mappingDownloadStatus = "映射表已下载，但无法写入版本信息。"
            loadItemMappings()
            return
        }
        loadItemMappings()
        mappingDownloadStatus = "已下载 " + itemMappings.length + " 项映射表（Minecraft " + gameVersion + "）。"
    }

    function downloadMappings(version) {
        if (mappingDownloadInProgress)
            return
        var requestedVersion = version ? version.trim() : ""
        mappingDownloadInProgress = true
        mappingDataReady = false
        mappingVersionReady = false
        mappingDownloadFailed = false
        downloadedMappingData = ""
        downloadedMappingVersion = ""
        mappingDownloadSource = requestedVersion.length
                              ? "https://raw.githubusercontent.com/Plagiatus/ForeverIds/"
                                + encodeURIComponent(requestedVersion) + "/items/items.min.json"
                              : Constants.url_itemMappings
        mappingDownloadStatus = requestedVersion.length
                              ? "正在下载 " + requestedVersion + " 的映射表…"
                              : "正在下载最新映射表…"

        XHR.sendRequest(mappingDownloadSource, function(response) {
            mappingDataReady = true
            if (response.status !== 200 || !validItemMappings(response.content)) {
                mappingDownloadFailed = true
                mappingDownloadStatus = "映射表数据无效或下载失败。"
            } else {
                downloadedMappingData = response.content
            }
            finishMappingDownload()
        })
        if (requestedVersion.length) {
            downloadedMappingVersion = requestedVersion
            mappingVersionReady = true
            finishMappingDownload()
            return
        }
        XHR.sendRequest(Constants.url_itemMappingTags, function(response) {
            mappingVersionReady = true
            try {
                var tags = response.status === 200 ? JSON.parse(response.content) : []
                if (!Array.isArray(tags) || !tags.length || typeof tags[0].name !== "string"
                        || !tags[0].name.length)
                    throw new Error("missing version")
                downloadedMappingVersion = tags[0].name
            } catch (error) {
                mappingDownloadFailed = true
                mappingDownloadStatus = "无法获取映射表的游戏版本。"
            }
            finishMappingDownload()
        })
    }

    function downloadLatestMappings() {
        downloadMappings("")
    }

    function fetchHistoricalMappingTags(page, versions) {
        var tagsUrl = "https://api.github.com/repos/Plagiatus/ForeverIds/tags?per_page=100&page=" + page
        XHR.sendRequest(tagsUrl, function(response) {
            if (response.status !== 200) {
                historicalVersionsLoading = false
                historicalVersionsStatus = "无法读取 GitHub 历史版本列表。"
                return
            }
            var tags = []
            try { tags = JSON.parse(response.content) }
            catch (error) { tags = [] }
            if (!Array.isArray(tags)) {
                historicalVersionsLoading = false
                historicalVersionsStatus = "GitHub 返回的历史版本列表无效。"
                return
            }
            for (var index = 0; index < tags.length; ++index) {
                var tag = tags[index]
                if (tag && typeof tag.name === "string" && tag.name.length
                        && versions.indexOf(tag.name) < 0)
                    versions.push(tag.name)
            }
            if (tags.length === 100) {
                fetchHistoricalMappingTags(page + 1, versions)
                return
            }
            // GitHub returns tags newest-first.  Retain that order because it
            // also remains meaningful for snapshot and pre-release names.
            historicalMappingVersions = versions
            historicalVersionsLoading = false
            historicalVersionsLoaded = true
            historicalVersionsStatus = historicalMappingVersions.length
                                     ? "已读取 " + historicalMappingVersions.length + " 个版本标签。"
                                     : "未找到可下载的版本标签。"
        })
    }

    function loadHistoricalMappingVersions() {
        if (historicalVersionsLoading || historicalVersionsLoaded)
            return
        historicalVersionsLoading = true
        historicalVersionsStatus = "正在从 GitHub 读取版本列表…"
        fetchHistoricalMappingTags(1, [])
    }

    function loadItemMappings() {
        loadGameVersion()
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

    function refreshItemMappings() {
        iconRevision += 1
        loadItemMappings()
    }

    function filterItems() {
        var keyword = itemSearch.trim().toLowerCase()
        var matches = []
        for (var index = 0; index < itemMappings.length; ++index) {
            var entry = itemMappings[index]
            var textureMatched = hasMappedTexture(entry.itemId)
            if ((sourceFilter === 1 && !entry.builtIn)
                    || (sourceFilter === 2 && entry.builtIn)
                    || (sourceFilter === 3 && textureMatched))
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

    XCFileDialog {
        id: minecraftJarDialog
        nameFilters: ["Minecraft game archive (*.jar)", "All files (*)"]
        onAccepted: {
            root.importProgress = 0
            root.importStatus = "正在准备导入本地游戏资源…"
            minecraftImporter.startImportGameJar(selectedFile.toString(), root.itemsRootPath)
        }
    }

    Connections {
        target: minecraftImporter
        function onProgressChanged(value, status) {
            root.importProgress = value
            root.importStatus = status
        }
        function onImportFinished(report) {
            if (!report.ok) {
                root.importProgress = 0
                root.importStatus = report.message
                return
            }
            root.importProgress = 96
            root.pendingImportMessage = report.message
            root.importStatus = "资源文件已生成，正在等待写入完成并刷新物品映射表…"
            refreshAfterImport.start()
        }
    }

    Timer {
        id: refreshAfterImport
        interval: 900
        repeat: false
        onTriggered: {
            root.refreshItemMappings()
            root.importProgress = 100
            root.importStatus = root.pendingImportMessage
            root.pendingImportMessage = ""
        }
    }

    Flickable {
        id: settingsFlickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: settingsContent.height
        boundsBehavior: Flickable.StopAtBounds

        Column {
        id: settingsContent
        width: Math.max(0, settingsFlickable.width - 14)
        height: implicitHeight
        spacing: 12

        SettingsPageHeader {
            id: header
            width: parent.width
            title: "物品映射表"
            subtitle: "读取当前 Minecraft 原版物品清单；图标按命名空间存储在 assets/minecraft/items/assets/<namespace>/。"
        }

        ContentBar {
            id: importBar
            width: parent.width
            expanded: true
            title: "从本地游戏中更新物品贴图"
            subtitle: "选择 Minecraft 客户端 .jar；资源会提取到 items/temp，并依据模型配置生成方块物品栏图标。"
            contentHeight: statusText.y + statusText.height + 16

            TextButton {
                x: 16
                y: 70
                width: 160
                height: 32
                radius: 7
                text: minecraftImporter.importing || refreshAfterImport.running ? "正在导入…" : "选择游戏 .jar"
                textSize: 12
                widthBorderSize: 10
                enabled: !minecraftImporter.importing && !refreshAfterImport.running
                buttonColor: Colors.changeA(Colors.border, 0.72)
                textColor: "#1b1b1b"
                onClicked: minecraftJarDialog.openXC(false, "minecraftGameJar")
            }

            Rectangle {
                x: 188
                y: 76
                width: Math.max(120, parent.width - x - 16)
                height: 12
                radius: 6
                color: Colors.changeA(Colors.background, 0.7)
                visible: minecraftImporter.importing || root.importProgress > 0

                Rectangle {
                    width: parent.width * root.importProgress / 100
                    height: parent.height
                    radius: parent.radius
                    color: Colors.border
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }

            XCText {
                id: statusText
                x: 188
                y: 96
                width: parent.width - x - 16
                xcText: root.importStatus.length ? root.importStatus : "未选择游戏文件；不会删除已有的自定义物品图标。"
                onCenter: false
                xcFontSize: 12
                boldFont: false
                wrapMode: Text.Wrap
                textColor: root.importStatus.indexOf("失败") >= 0 || root.importStatus.indexOf("无法") >= 0 ? Colors.error : Colors.banned
            }
        }

        ContentBar {
            id: addMappingBar
            width: parent.width
            expanded: true
            title: "添加自定义物品"
            subtitle: "自定义条目可删除，原版条目始终保持只读。"
            contentHeight: addFields.y + addFields.height + (root.formError.length ? 24 : 0) + 16

            Flow {
                id: addFields
                x: 16
                y: 70
                width: parent.width - 32
                spacing: 10

                Column {
                    width: Math.min(parent.width, Math.max(190, parent.width * 0.34))
                    spacing: 5
                    XCText { xcText: "物品 ID"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    XCTextField { id: customIdInput; width: parent.width; placeholderText: "examplemod:machine" }
                }
                Column {
                    width: Math.min(parent.width, Math.max(220, parent.width - parent.spacing * 2
                                                          - Math.min(parent.width, Math.max(190, parent.width * 0.34)) - 126))
                    spacing: 5
                    XCText { xcText: "物品图标"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    XCTextField { id: customIconInput; width: parent.width; placeholderText: "选择本地 PNG、JPG、WebP 或 BMP 图像" }
                }
                Column {
                    width: Math.min(126, parent.width)
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
            subtitle: "Minecraft " + root.gameVersion + " · 共 " + root.itemMappings.length + " 项，当前显示 " + root.filteredItems.length + " 项。"
            contentHeight: root.listContentHeight

            TextButton {
                id: mappingDownloadArrow
                anchors.right: parent.right
                anchors.rightMargin: 16
                y: 14
                width: 32
                height: 32
                radius: 7
                text: "⌄"
                textSize: 16
                widthBorderSize: 0
                enabled: !root.mappingDownloadInProgress
                buttonColor: Colors.changeA(Colors.border, 0.72)
                textColor: "#1b1b1b"
                onClicked: mappingDownloadMenu.opened = !mappingDownloadMenu.opened
            }

            TextButton {
                id: mappingDownloadButton
                anchors.right: mappingDownloadArrow.left
                anchors.rightMargin: 2
                y: 14
                width: 140
                height: 32
                radius: 7
                text: root.mappingDownloadInProgress ? "正在下载…" : "下载最新的映射表"
                textSize: 12
                widthBorderSize: 10
                enabled: !root.mappingDownloadInProgress
                buttonColor: Colors.changeA(Colors.border, 0.72)
                textColor: "#1b1b1b"
                onClicked: root.downloadLatestMappings()
            }

            TextButton {
                anchors.right: mappingDownloadButton.left
                anchors.rightMargin: 8
                y: 14
                width: 72
                height: 32
                radius: 7
                text: "刷新"
                textSize: 12
                widthBorderSize: 10
                buttonColor: Colors.pressed
                onClicked: root.refreshItemMappings()
            }

            Rectangle {
                id: mappingDownloadMenu
                property bool opened: false
                z: 30
                anchors.top: mappingDownloadButton.bottom
                anchors.topMargin: 6
                anchors.right: mappingDownloadArrow.right
                width: 158
                height: opened ? 42 : 0
                radius: 8
                clip: true
                visible: opened
                color: Colors.changeA(Colors.foreground, 0.98)
                border.width: 1
                border.color: Colors.changeA(Colors.text, 0.12)

                layer.enabled: true
                layer.effect: XCShadow { shadowVerticalOffset: 5; shadowHorizontalOffset: 0; shadowBlur: 0.65 }

                TextButton {
                    x: 5
                    y: 5
                    width: parent.width - 10
                    height: 32
                    radius: 6
                    text: "选择历史版本"
                    textSize: 12
                    boldFont: false
                    widthBorderSize: 8
                    buttonColor: Colors.transparent
                    firedColor: Colors.changeA(Colors.fired, 0.38)
                    pressedColor: Colors.changeA(Colors.border, 0.58)
                    onClicked: {
                        mappingDownloadMenu.opened = false
                        SignalBus.sendToMain("Popup.show", {
                            "component": Constants.popupMappingHistory,
                            "properties": { "settingsPage": root }
                        })
                    }
                }
            }

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
                z: 20
                anchors.right: parent.right
                anchors.rightMargin: 16
                y: 70
                per_width: 108
                per_height: 32
                options: ["全部", "原版", "自定义", "未匹配"]
                onClicked: {
                    root.sourceFilter = selected
                    root.filterItems()
                }
            }

            XCText {
                x: 16
                y: 108
                width: parent.width - 32
                xcText: root.mappingDownloadStatus
                visible: root.mappingDownloadStatus.length > 0
                onCenter: false
                xcFontSize: 12
                boldFont: false
                elide: Text.ElideRight
                textColor: root.mappingDownloadStatus.indexOf("失败") >= 0
                           || root.mappingDownloadStatus.indexOf("无法") >= 0
                           ? Colors.error : Colors.banned
            }

            Rectangle {
                x: 16
                y: 130
                width: parent.width - 32
                height: 1
                color: Colors.changeA(Colors.text, 0.10)
            }

            Item {
                id: tableHeader
                x: 16
                y: 138
                width: parent.width - 32
                height: 24
                XCText { x: 8; width: 48; xcText: "图标"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { x: 52; width: parent.width - 324; xcText: "物品 ID"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { x: parent.width - 260; width: 62; xcText: "来源"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { x: parent.width - 180; width: 94; xcText: "映射状态"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { x: parent.width - 78; width: 70; xcText: "操作"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
            }

            ListView {
                id: itemTable
                x: 16
                y: 166
                width: parent.width - 32
                height: parent.height - y - 12
                clip: true
                spacing: 3
                model: root.filteredItems

                delegate: Rectangle {
                    id: itemDelegate
                    required property var modelData
                    width: ListView.view.width
                    height: 46
                    radius: 7
                    color: Colors.changeA(Colors.background, 0.22)
                    border.width: 1
                    border.color: Colors.changeA(Colors.text, 0.05)

                    property string iconSource: root.fileUrl(root.itemIconPath(itemDelegate.modelData.itemId))
                                                + "?revision=" + root.iconRevision
                    property bool textureMapped: root.hasMappedTexture(itemDelegate.modelData.itemId)

                    Rectangle {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        radius: 5
                        clip: true
                        visible: itemDelegate.iconSource.length > 0
                        color: Colors.transparent
                        Image {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            z: 1
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
                        x: 52
                        width: parent.width - 324
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
                            var itemId = itemDelegate.modelData.itemId
                            SignalBus.sendToMain("Popup.show", {
                                "component": Constants.popupNotice,
                                "properties": {
                                    "title": "删除自定义物品",
                                    "content": "确定删除“" + itemId + "”吗？此操作会更新 custom-items.json。",
                                    "doubleButton": true
                                },
                                "callback": function(result) {
                                    if (result === 1)
                                        root.removeCustomItem(itemId)
                                }
                            })
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

    }

    Rectangle {
        id: pageScrollBar
        anchors.top: settingsFlickable.top
        anchors.bottom: settingsFlickable.bottom
        anchors.right: settingsFlickable.right
        width: 7
        radius: width / 2
        z: 10
        visible: settingsFlickable.contentHeight > settingsFlickable.height
        color: Colors.changeA(Colors.background, 0.30)

        readonly property real maxContentY: Math.max(0, settingsFlickable.contentHeight - settingsFlickable.height)
        readonly property real maxThumbY: Math.max(0, height - pageScrollThumb.height)

        Rectangle {
            id: pageScrollThumb
            width: parent.width
            height: Math.max(34, parent.height * settingsFlickable.height
                             / Math.max(settingsFlickable.height, settingsFlickable.contentHeight))
            y: pageScrollBar.maxContentY > 0
               ? Math.max(0, Math.min(pageScrollBar.maxThumbY,
                                      settingsFlickable.contentY / pageScrollBar.maxContentY * pageScrollBar.maxThumbY))
               : 0
            radius: width / 2
            color: pageScrollHandle.containsMouse || pageScrollHandle.pressed
                   ? Colors.changeA(Colors.border, 0.92)
                   : Colors.changeA(Colors.banned, 0.62)

            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
                id: pageScrollHandle
                anchors.fill: parent
                hoverEnabled: true
                property real previousY: 0
                onPressed: previousY = mouseY
                onPositionChanged: {
                    if (!pressed || pageScrollBar.maxThumbY <= 0)
                        return
                    var targetY = Math.max(0, Math.min(pageScrollBar.maxThumbY,
                                                       pageScrollThumb.y + mouseY - previousY))
                    settingsFlickable.contentY = targetY / pageScrollBar.maxThumbY * pageScrollBar.maxContentY
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: function(mouse) {
                if (pageScrollBar.maxThumbY <= 0)
                    return
                var targetY = Math.max(0, Math.min(pageScrollBar.maxThumbY,
                                                   mouse.y - pageScrollThumb.height / 2))
                settingsFlickable.contentY = targetY / pageScrollBar.maxThumbY * pageScrollBar.maxContentY
            }
        }
    }
}
