pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

Item {
    id: root
    readonly property string itemsRootPath: APP_DIRPATH + "/assets/minecraft/items"
    property var items: []
    property var customItems: []
    property var filteredItems: []
    property string currentVersion: "尚未导入"
    property string catalogSummary: "从游戏资源生成物品列表和默认图标。"
    property string formError: ""
    property int filter: 0
    property int iconRevision: 0
    property bool showSnapshots: false
    property string importSource: "local"
    property string onlineVersion: ""
    property bool advancedOpen: false
    property var importedVersions: []
    property string switchError: ""
    property var versionCatalog: MinecraftAssetImporter.versions
    property var localInfo: MinecraftAssetImporter.localInfo
    readonly property bool busy: MinecraftAssetImporter.importing
    readonly property bool serverFallbackAvailable: !busy && MinecraftAssetImporter.lastReport.canUseServer === true
            && MinecraftAssetImporter.lastReport.cancelled !== true
            && MinecraftAssetImporter.lastReport.requestSource === importSource
            && MinecraftAssetImporter.lastReport.requestPath === (importSource === "local" ? localField.text.trim() : "")
            && MinecraftAssetImporter.lastReport.requestVersion === (importSource === "download" ? onlineVersion : "")
    readonly property var pickerVersions: {
        var keyword = versionSearch.text.trim().toLowerCase()
        return root.versionCatalog.filter(function(version) {
            return (root.showSnapshots || version.type === "release")
                    && (!keyword.length || version.id.toLowerCase().indexOf(keyword) >= 0)
        })
    }

    XCFile { id: file }

    function readJson(path, fallback) {
        try { return JSON.parse(file.read(path)) }
        catch (error) { return fallback }
    }
    function validItemId(id) {
        if (typeof id !== "string" || !/^[a-z0-9_.-]+:[a-z0-9_./-]+$/.test(id)) return false
        if (id.split(":")[0] === "." || id.split(":")[0] === "..") return false
        return !id.split(":")[1].split("/").some(function(segment) {
            return !segment.length || segment === "." || segment === ".."
        })
    }
    function loadItems() {
        Global.reloadMinecraftResources()
        var pack = Global.minecraftPackPath
        var catalog = pack.length ? readJson(pack + "/catalog.json", null) : null
        var loaded = []
        currentVersion = "尚未导入"
        if (catalog && catalog.schemaVersion === 2 && Array.isArray(catalog.items)) {
            currentVersion = catalog.gameVersion
            catalogSummary = "官方注册表 · " + catalog.itemCount + " 项物品 · "
                    + catalog.rendered + " 个默认图标 · " + catalog.approximate
                    + " 个近似图标 · " + catalog.missing + " 项缺少图标"
            loaded = catalog.items
        } else {
            loaded = readJson(itemsRootPath + "/items.json", [])
            if (!Array.isArray(loaded)) loaded = []
            catalogSummary = loaded.length ? "当前为旧版物品列表。完成官方数据导入后自动切换，已有自定义图标保留。"
                                            : "尚无物品资源。选择本地游戏，或在线下载后导入。"
        }
        var combined = []
        for (var i = 0; i < loaded.length; ++i) {
            var item = loaded[i]
            if (!item || !item.name || item.name === "minecraft:air") continue
            combined.push({itemId: item.name, builtIn: true,
                           iconStatus: item.iconStatus || (file.exists(Global.getItemTexturePath(item.name)) ? "legacy" : "missing"),
                           iconReason: item.iconReason || ""})
        }
        customItems = readJson(itemsRootPath + "/custom-items.json", [])
        if (!Array.isArray(customItems)) customItems = []
        var seen = ({})
        for (var n = 0; n < combined.length; ++n) seen[combined[n].itemId] = true
        for (var c = 0; c < customItems.length; ++c) {
            var custom = customItems[c]
            if (!custom || !validItemId(custom.itemId) || seen[custom.itemId]) continue
            combined.push({itemId: custom.itemId, builtIn: false,
                           iconStatus: file.exists(Global.getItemTexturePath(custom.itemId)) ? "custom" : "missing", iconReason: ""})
        }
        items = combined
        iconRevision += 1
        filterItems()
    }
    function filterItems() {
        var keyword = searchField.text.trim().toLowerCase()
        filteredItems = items.filter(function(item) {
            return (!keyword.length || item.itemId.indexOf(keyword) >= 0)
                    && (root.filter !== 1 || item.builtIn)
                    && (root.filter !== 2 || !item.builtIn)
                    && (root.filter !== 3 || item.iconStatus === "approximate")
                    && (root.filter !== 4 || item.iconStatus === "missing")
        }).sort(function(a, b) {
            var aExact = a.itemId === keyword || a.itemId.split(":")[1] === keyword
            var bExact = b.itemId === keyword || b.itemId.split(":")[1] === keyword
            return aExact !== bExact ? (aExact ? -1 : 1) : a.itemId.localeCompare(b.itemId)
        })
    }
    function iconSource(item) {
        var path = Global.getItemTexturePath(item.itemId)
        return item.iconStatus === "missing" ? "qrc:/assets/gui/element/Item.png"
                : "file:///" + path.replace(/\\/g, "/") + "?revision=" + iconRevision
    }
    function statusLabel(status) {
        switch (status) {
        case "rendered": return "默认图标"
        case "approximate": return "近似预览"
        case "custom": return "自定义图标"
        case "legacy": return "已有图标"
        case "empty": return "无默认图标"
        default: return "缺少图标"
        }
    }
    function importOptions(generator) {
        return {itemsRoot: itemsRootPath, source: importSource,
                sourcePath: importSource === "local" ? localField.text.trim() : "",
                version: importSource === "download" ? onlineVersion : "",
                javaPath: javaField.text.trim(), librariesPath: librariesField.text.trim(),
                allowNetwork: networkCheck.checked, rebuild: rebuildCheck.checked,
                generator: generator || "client"}
    }
    function startImport(generator) {
        var settings = {source: importSource, version: onlineVersion, sourcePath: localField.text.trim(),
                        javaPath: javaField.text.trim(), librariesPath: librariesField.text.trim(),
                        allowNetwork: networkCheck.checked}
        file.writeAtomic(itemsRootPath + "/import-settings.json", JSON.stringify(settings))
        MinecraftAssetImporter.startImport(importOptions(generator))
    }
    function saveCustomItem() {
        var id = customId.text.trim().toLowerCase()
        formError = ""
        if (!validItemId(id)) { formError = "请输入有效的命名空间 ID，例如 examplemod:machine。"; return }
        for (var i = 0; i < items.length; ++i)
            if (items[i].itemId === id) { formError = "物品 ID 已存在。"; return }
        if (!customIcon.text.trim().length) { formError = "请选择自定义图标。"; return }
        // Custom icons always live outside immutable vanilla packs.
        var destination = itemsRootPath + "/assets/" + id.replace(":", "/") + ".png"
        if (!file.copy(customIcon.text.trim(), destination)) { formError = "无法复制图标。"; return }
        var next = customItems.slice()
        next.push({itemId: id})
        if (!file.writeAtomic(itemsRootPath + "/custom-items.json", JSON.stringify(next))) {
            file.remove_file(destination)
            formError = "无法保存自定义物品。"
            return
        }
        customId.text = ""
        customIcon.text = ""
        loadItems()
    }
    function removeCustomItem(id) {
        if (!validItemId(id)) return
        var next = customItems.filter(function(item) { return item.itemId !== id })
        if (file.writeAtomic(itemsRootPath + "/custom-items.json", JSON.stringify(next))) {
            file.remove_file(itemsRootPath + "/assets/" + id.replace(":", "/") + ".png")
            loadItems()
        } else formError = "无法删除自定义物品。"
    }
    Component.onCompleted: {
        var settings = readJson(itemsRootPath + "/import-settings.json", {})
        onlineVersion = settings.version || ""
        importSource = settings.source === "download" ? "download" : "local"
        javaField.text = settings.javaPath || ""
        librariesField.text = settings.librariesPath || ""
        localField.text = settings.sourcePath || settings.clientJar || ""
        networkCheck.checked = settings.allowNetwork !== false
        loadItems()
    }
    Connections {
        target: MinecraftAssetImporter
        function onImportFinished(report) {
            if (report.ok) root.loadItems()
        }
    }
    Timer {
        id: inspectTimer; interval: 400
        onTriggered: MinecraftAssetImporter.inspectLocal(localField.text)
    }
    XCFileDialog { id: jarDialog; nameFilters: ["Minecraft 客户端 (*.jar)"]; onAccepted: localField.text = selectedFile.toString() }
    XCFolderDialog { id: gameDialog; title: "选择游戏目录或版本目录"; onAccepted: localField.text = selectedFolder.toString() }
    XCFolderDialog { id: librariesDialog; title: "选择 libraries 依赖目录"; onAccepted: librariesField.text = selectedFolder.toString() }
    XCFileDialog { id: javaDialog; nameFilters: ["Java 可执行文件 (java.exe java)", "所有文件 (*)"]; onAccepted: javaField.text = selectedFile.toString() }
    XCFileDialog { id: iconDialog; nameFilters: ["图片 (*.png *.jpg *.jpeg *.webp *.bmp)"]; onAccepted: customIcon.text = selectedFile.toString() }

    SettingsSection {
        id: scroll
        title: "物品资源"
        anchors.fill: parent

        SettingsCard {
            title: "导入物品资源"
            description: "导入 Minecraft Java 1.13+ 基础物品。可选择整合包里的游戏文件，不包含模组新增物品。"
            contentHeight: importForm.height
            Column {
                id: importForm
                width: parent.width
                spacing: 10
                Row {
                    width: parent.width; spacing: 8
                    SettingsActionButton {
                        objectName: "minecraftLocalSourceButton"
                        width: (parent.width - 8) / 2; text: "本地游戏"; enabled: !root.busy
                        buttonColor: root.importSource === "local" ? Colors.changeA(Colors.border, 0.28) : Colors.changeA(Colors.pressed, 0.72)
                        onClicked: root.importSource = "local"
                    }
                    SettingsActionButton {
                        objectName: "minecraftDownloadSourceButton"
                        width: (parent.width - 8) / 2; text: "在线下载"; enabled: !root.busy
                        buttonColor: root.importSource === "download" ? Colors.changeA(Colors.border, 0.28) : Colors.changeA(Colors.pressed, 0.72)
                        onClicked: root.importSource = "download"
                    }
                }
                Column {
                    objectName: "minecraftLocalForm"; width: parent.width; spacing: 8; visible: root.importSource === "local"
                    XCTextField {
                        id: localField; objectName: "minecraftLocalPathField"; width: parent.width
                        placeholderText: "选择客户端 JAR 或游戏目录，自动识别版本"; enabled: !root.busy
                        onTextChanged: inspectTimer.restart()
                    }
                    Flow {
                        width: parent.width; spacing: 8
                        SettingsActionButton { text: "选择游戏文件…"; enabled: !root.busy; onClicked: jarDialog.openXC(false, "minecraftClient") }
                        SettingsActionButton { text: "选择目录…"; enabled: !root.busy; onClicked: gameDialog.open() }
                    }
                    XCText {
                        objectName: "minecraftDetectedVersion"; width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
                        xcText: !localField.text.trim().length ? "版本会自动识别，无需手动选择。"
                                : MinecraftAssetImporter.inspectingLocal || inspectTimer.running ? "正在识别本地游戏…"
                                : root.localInfo.sourcePath === localField.text.trim() ? root.localInfo.message || "" : "等待识别…"
                        textColor: root.localInfo.sourcePath === localField.text.trim() && root.localInfo.ok === false ? Colors.error : Colors.banned
                    }
                }
                Column {
                    objectName: "minecraftDownloadForm"; width: parent.width; spacing: 8; visible: root.importSource === "download"
                    Row {
                        width: parent.width; spacing: 8
                        XCTextField { id: versionField; objectName: "minecraftVersionField"; width: Math.max(100, parent.width - 116); readOnly: true; text: root.onlineVersion; placeholderText: "选择要下载的版本"; enabled: !root.busy }
                        SettingsActionButton {
                            objectName: "minecraftVersionPickerButton"; text: "选择版本…"; enabled: !root.busy
                            onClicked: { versionPicker.open(); if (!root.versionCatalog.length) MinecraftAssetImporter.refreshVersions(root.itemsRootPath, networkCheck.checked) }
                        }
                    }
                    XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned; xcText: networkCheck.checked ? "从官方下载客户端和所需依赖，已有文件直接复用。" : "当前仅使用缓存。如需下载，请在高级选项允许联网补齐。" }
                }
                SettingsActionButton {
                    objectName: "minecraftAdvancedButton"; text: root.advancedOpen ? "收起高级选项" : "高级选项…"
                    onClicked: root.advancedOpen = !root.advancedOpen
                }
                Column {
                    objectName: "minecraftAdvancedForm"; width: parent.width; spacing: 8; visible: root.advancedOpen
                    XCText { xcText: "Java（留空自动查找）"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    Row {
                        width: parent.width; spacing: 8
                        XCTextField { id: javaField; objectName: "minecraftJavaField"; width: Math.max(100, parent.width - 74); placeholderText: "java.exe 或 Java 安装目录"; enabled: !root.busy }
                        SettingsActionButton { text: "浏览…"; enabled: !root.busy; onClicked: javaDialog.openXC(false, "minecraftJava") }
                    }
                    XCText { xcText: "依赖目录（留空自动查找）"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    Row {
                        width: parent.width; spacing: 8
                        XCTextField { id: librariesField; objectName: "minecraftLibrariesField"; width: Math.max(100, parent.width - 74); placeholderText: "libraries 目录"; enabled: !root.busy }
                        SettingsActionButton { text: "浏览…"; enabled: !root.busy; onClicked: librariesDialog.open() }
                    }
                    XCCheckBox { id: networkCheck; objectName: "minecraftNetworkCheck"; text: "允许联网补齐缺失文件"; height: 32; checked: true; enabled: !root.busy }
                    XCCheckBox { id: rebuildCheck; text: "重新生成已有图标"; height: 32; enabled: !root.busy }
                    SettingsActionButton {
                        objectName: "minecraftServerFallbackButton"
                        visible: root.serverFallbackAvailable
                        text: MinecraftAssetImporter.lastReport.serverCached ? "使用已缓存的服务端导入"
                              : "下载服务端并导入（约 " + Math.ceil((MinecraftAssetImporter.lastReport.serverSize || 0) / 1048576) + " MiB）"
                        enabled: networkCheck.checked || MinecraftAssetImporter.lastReport.serverCached === true
                        onClicked: root.startImport("server")
                    }
                    XCText {
                        width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned
                        visible: !root.busy && MinecraftAssetImporter.lastReport.ok === false && (MinecraftAssetImporter.lastReport.message || "").indexOf("\n") >= 0
                        xcText: MinecraftAssetImporter.lastReport.message || ""
                    }
                }
                Flow {
                    width: parent.width; spacing: 12
                    SettingsActionButton {
                        objectName: "minecraftImportButton"; text: root.busy ? "正在导入…" : "导入并启用"
                        primary: true
                        enabled: !root.busy && (root.importSource === "download" ? root.onlineVersion.length > 0
                                 : !MinecraftAssetImporter.inspectingLocal && !inspectTimer.running && root.localInfo.ok === true && root.localInfo.sourcePath === localField.text.trim())
                        onClicked: root.startImport("client")
                    }
                    SettingsActionButton { text: "取消"; visible: root.busy; onClicked: MinecraftAssetImporter.cancel() }
                }
                Rectangle {
                    width: parent.width; height: 6; radius: 3
                    visible: root.busy || MinecraftAssetImporter.progress > 0
                    color: Colors.changeA(Colors.background, 0.6)
                    Rectangle { width: parent.width * MinecraftAssetImporter.progress / 100; height: parent.height; radius: 3; color: Colors.border }
                }
                XCText {
                    width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
                    xcText: MinecraftAssetImporter.status.length ? MinecraftAssetImporter.status.split("\n")[0]
                            + (root.serverFallbackAvailable && !root.advancedOpen ? " 可在高级选项尝试服务端备用导入。" : "")
                            : networkCheck.checked ? "Java 和依赖会自动查找。切换页面不会中断导入。" : "当前仅使用本地文件和缓存。切换页面不会中断导入。"
                    textColor: !root.busy && MinecraftAssetImporter.lastReport.ok === false && !MinecraftAssetImporter.lastReport.cancelled ? Colors.error : Colors.banned
                }
            }
        }
        SettingsCard {
            title: "当前资源 · " + root.currentVersion
            description: root.catalogSummary
            contentHeight: itemForm.height
            headerActions: SettingsActionButton {
                objectName: "minecraftSwitchVersionButton"
                text: "切换版本"; enabled: !root.busy
                onClicked: {
                    root.importedVersions = MinecraftAssetImporter.importedVersions(root.itemsRootPath)
                    root.switchError = ""
                    importedSearch.text = ""
                    importedPicker.open()
                }
            }
            Column {
                id: itemForm
                width: parent.width
                spacing: 10
                Flow {
                    width: parent.width; spacing: 8; z: 2
                    XCTextField { id: searchField; width: Math.max(160, parent.width - 150); placeholderText: "按物品 ID 搜索"; onTextChanged: root.filterItems() }
                    ComboBox {
                        per_width: 132; options: ["全部", "原版", "自定义", "近似图标", "缺少图标"]
                        onClicked: { root.filter = selected; root.filterItems() }
                        z: 20
                    }
                }
                XCText { xcText: "显示 " + root.filteredItems.length + " / " + root.items.length + " 项"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                ListView {
                    id: itemList
                    objectName: "minecraftItemList"
                    width: parent.width
                    height: Math.max(220, Math.min(420, root.height * 0.42))
                    clip: true
                    spacing: 4
                    model: root.filteredItems
                    Controls.ScrollBar.vertical: XCScrollBar {}
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        width: itemList.width - 12
                        height: 48
                        radius: 6
                        color: Colors.changeA(Colors.background, 0.26)
                        Image {
                            x: 8; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32
                            source: root.iconSource(row.modelData); fillMode: Image.PreserveAspectFit; smooth: false; asynchronous: true
                        }
                        XCText {
                            x: 50; anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(60, parent.width - 250)
                            xcText: row.modelData.itemId; onCenter: false; xcFontSize: 12; boldFont: false; elide: Text.ElideMiddle
                        }
                        XCText {
                            x: Math.max(120, parent.width - 188); anchors.verticalCenter: parent.verticalCenter; width: 102
                            xcText: root.statusLabel(row.modelData.iconStatus); onCenter: false; xcFontSize: 12; boldFont: false
                            textColor: row.modelData.iconStatus === "missing" ? Colors.error : row.modelData.iconStatus === "approximate" ? Colors.banned : Colors.border
                        }
                        MouseArea {
                            id: tooltipArea; anchors.fill: parent; acceptedButtons: Qt.NoButton; hoverEnabled: true
                        }
                        Controls.ToolTip.visible: tooltipArea.containsMouse && row.modelData.iconReason.length > 0
                        Controls.ToolTip.text: row.modelData.iconReason
                        Controls.ToolTip.delay: 400
                        SettingsActionButton {
                            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                            text: "删除"; height: 28; visible: !row.modelData.builtIn; enabled: !root.busy
                            onClicked: root.removeCustomItem(row.modelData.itemId)
                        }
                    }
                    XCText {
                        anchors.centerIn: parent; width: parent.width - 24
                        xcText: root.items.length ? "没有匹配的物品" : "导入游戏资源后，物品会显示在这里"
                        visible: !itemList.count; xcFontSize: 13; boldFont: false; textColor: Colors.banned
                    }
                }
            }
        }
        SettingsCard {
            title: "添加自定义物品"
            description: "自定义图标独立保存，切换原版资源版本时继续保留。"
            contentHeight: customForm.height
            Column {
                id: customForm; width: parent.width; spacing: 10
                XCTextField { id: customId; width: parent.width; placeholderText: "物品 ID，例如 examplemod:machine"; enabled: !root.busy }
                XCTextField { id: customIcon; width: parent.width; placeholderText: "选择本地物品图标"; enabled: !root.busy }
                Flow {
                    width: parent.width; spacing: 8
                    SettingsActionButton { text: "选择图标…"; enabled: !root.busy; onClicked: iconDialog.openXC(false, "customItemIcon") }
                    SettingsActionButton { text: "添加物品"; primary: true; enabled: !root.busy; onClicked: root.saveCustomItem() }
                }
                XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.error; xcText: root.formError; visible: root.formError.length > 0 }
            }
        }
    }
    PopupFrame {
        id: importedPicker
        parent: Controls.Overlay.overlay
        visible: false
        manageVisibility: true
        closeOnScrim: true
        title: "切换已导入的版本"
        dialogWidth: 460
        dialogHeight: 440
        actions: [
            ActionButton {
                text: "关闭"
                onClicked: importedPicker.close()
            }
        ]
        Column {
            x: 24
            y: 82
            width: importedPicker.availableWidth
            spacing: 10
            XCText { width: parent.width; xcText: "直接应用本地资源，无需下载或重新生成。"; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
            XCTextField { id: importedSearch; width: parent.width; placeholderText: "搜索已导入版本" }
            ListView {
                id: importedList
                width: parent.width; height: Math.max(60, importedPicker.availableHeight - y - 82)
                clip: true; spacing: 4
                model: root.importedVersions.filter(function(entry) { return entry.version.toLowerCase().indexOf(importedSearch.text.trim().toLowerCase()) >= 0 })
                Controls.ScrollBar.vertical: XCScrollBar {}
                delegate: SettingsActionButton {
                    required property var modelData
                    objectName: "minecraftImportedChoice_" + modelData.version
                    width: importedList.width - 12
                    text: modelData.version + (modelData.active ? " · 当前使用" : "") + " · " + modelData.itemCount + " 项物品"
                    enabled: !root.busy && !modelData.active
                    onClicked: {
                        if (MinecraftAssetImporter.switchVersion(root.itemsRootPath, modelData.pack)) importedPicker.close()
                        else {
                            root.switchError = MinecraftAssetImporter.lastReport.message
                            root.importedVersions = MinecraftAssetImporter.importedVersions(root.itemsRootPath)
                        }
                    }
                }
                XCText {
                    anchors.centerIn: parent; width: parent.width; onCenter: true; xcWrapMode: true; xcFontSize: 13; boldFont: false; textColor: Colors.banned
                    visible: !importedList.count
                    xcText: root.importedVersions.length ? "没有匹配的版本" : "暂无已导入版本，请先导入游戏资源。"
                }
            }
            XCText { width: parent.width; visible: root.switchError.length > 0; xcText: root.switchError; onCenter: false; xcWrapMode: true; xcFontSize: 12; textColor: Colors.error }
        }
    }
    PopupFrame {
        id: versionPicker
        parent: Controls.Overlay.overlay
        visible: false
        manageVisibility: true
        closeOnScrim: true
        title: "选择 Minecraft 版本"
        dialogWidth: 480
        dialogHeight: 560
        actions: [
            ActionButton {
                text: "关闭"
                onClicked: versionPicker.close()
            }
        ]
        Column {
            x: 24
            y: 82
            width: versionPicker.availableWidth
            spacing: 10
            XCTextField { id: versionSearch; width: parent.width; placeholderText: "搜索版本，例如 1.13" }
            Flow {
                width: parent.width; spacing: 12
                XCCheckBox { text: "显示测试版"; height: 32; checked: root.showSnapshots; onToggled: root.showSnapshots = checked }
                SettingsActionButton { text: MinecraftAssetImporter.loadingVersions ? "正在读取…" : networkCheck.checked ? "刷新官方列表" : "读取缓存列表"; enabled: !MinecraftAssetImporter.loadingVersions; onClicked: MinecraftAssetImporter.refreshVersions(root.itemsRootPath, networkCheck.checked) }
            }
            XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned; xcText: MinecraftAssetImporter.versionsStatus }
            ListView {
                id: versionsList; width: parent.width
                height: Math.max(100, versionPicker.availableHeight - y - 42)
                clip: true; spacing: 3; model: root.pickerVersions
                Controls.ScrollBar.vertical: XCScrollBar {}
                delegate: SettingsActionButton {
                    required property var modelData
                    objectName: "minecraftVersionChoice_" + modelData.id
                    width: versionsList.width - 12; text: modelData.label
                    onClicked: { root.onlineVersion = modelData.id; versionPicker.close() }
                }
            }
        }
    }
}
