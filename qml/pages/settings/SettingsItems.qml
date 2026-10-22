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
    property string catalogSummary: "选择版本后，从官方游戏数据生成完整物品列表和默认图标。"
    property string formError: ""
    property int filter: 0
    property int iconRevision: 0
    property bool showSnapshots: false
    property var versionCatalog: MinecraftAssetImporter.versions
    readonly property bool busy: MinecraftAssetImporter.importing
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
                                            : "尚无物品资源。请选择 Minecraft 版本并开始导入。"
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
    function startImport() {
        var settings = {version: versionField.text.trim(), javaPath: javaField.text.trim(), clientJar: jarField.text.trim()}
        file.writeAtomic(itemsRootPath + "/import-settings.json", JSON.stringify(settings))
        MinecraftAssetImporter.startImport({itemsRoot: itemsRootPath, version: settings.version,
                                            javaPath: settings.javaPath, clientJar: settings.clientJar,
                                            rebuild: rebuildCheck.checked})
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
        versionField.text = settings.version || ""
        javaField.text = settings.javaPath || ""
        jarField.text = settings.clientJar || ""
        loadItems()
    }
    Connections {
        target: MinecraftAssetImporter
        function onImportFinished(report) {
            if (report.ok) root.loadItems()
        }
    }
    XCFileDialog { id: jarDialog; nameFilters: ["Minecraft 客户端 (*.jar)"]; onAccepted: jarField.text = selectedFile.toString() }
    XCFileDialog { id: javaDialog; nameFilters: ["Java 可执行文件 (java.exe java)", "所有文件 (*)"]; onAccepted: javaField.text = selectedFile.toString() }
    XCFileDialog { id: iconDialog; nameFilters: ["图片 (*.png *.jpg *.jpeg *.webp *.bmp)"]; onAccepted: customIcon.text = selectedFile.toString() }

    Controls.ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        Column {
            width: scroll.availableWidth
            spacing: 16
            SettingsPageHeader { title: "物品资源"; width: parent.width }
            SettingsCard {
                title: "从官方游戏数据导入"
                description: "支持 Java 原版 1.13 起的正式版及后续测试版。首次导入需要下载对应游戏文件并运行 Java；完成后可离线使用。"
                contentHeight: importForm.height
                Column {
                    id: importForm
                    width: parent.width
                    spacing: 10
                    XCText { xcText: "Minecraft 版本"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    Row {
                        width: parent.width
                        spacing: 8
                        XCTextField { id: versionField; objectName: "minecraftVersionField"; width: Math.max(120, parent.width - 116); placeholderText: "例如 1.13、1.21.4；本地 JAR 可自动识别"; enabled: !root.busy }
                        SettingsActionButton {
                            objectName: "minecraftVersionPickerButton"
                            text: "选择版本…"; enabled: !root.busy
                            onClicked: { versionPicker.open(); if (!root.versionCatalog.length) MinecraftAssetImporter.refreshVersions(root.itemsRootPath) }
                        }
                    }
                    XCText { xcText: "本地客户端 JAR（可选，留空时从官方下载）"; width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    Row {
                        width: parent.width; spacing: 8
                        XCTextField { id: jarField; width: Math.max(120, parent.width - 74); placeholderText: "选择对应版本的原版客户端文件"; enabled: !root.busy }
                        SettingsActionButton { text: "浏览…"; enabled: !root.busy; onClicked: jarDialog.openXC(false, "minecraftClient") }
                    }
                    XCText { xcText: "Java 路径（可选，留空时自动查找已安装的 Java）"; width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    Row {
                        width: parent.width; spacing: 8
                        XCTextField { id: javaField; width: Math.max(120, parent.width - 74); placeholderText: "java.exe 或 Java 安装目录"; enabled: !root.busy }
                        SettingsActionButton { text: "浏览…"; enabled: !root.busy; onClicked: javaDialog.openXC(false, "minecraftJava") }
                    }
                    Flow {
                        width: parent.width; spacing: 12
                        SettingsActionButton { objectName: "minecraftImportButton"; text: root.busy ? "正在导入…" : "导入并启用"; enabled: !root.busy; onClicked: root.startImport() }
                        SettingsActionButton { text: "取消"; visible: root.busy; onClicked: MinecraftAssetImporter.cancel() }
                        XCCheckBox { id: rebuildCheck; text: "重新生成已有图标"; height: 32; enabled: !root.busy }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3
                        visible: root.busy || MinecraftAssetImporter.progress > 0
                        color: Colors.changeA(Colors.background, 0.6)
                        Rectangle { width: parent.width * MinecraftAssetImporter.progress / 100; height: parent.height; radius: 3; color: Colors.border }
                    }
                    XCText {
                        width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
                        xcText: MinecraftAssetImporter.status.length ? MinecraftAssetImporter.status : "已导入的版本会保存在本地。切换页面不会中断导入。"
                        textColor: !root.busy && MinecraftAssetImporter.lastReport.ok === false && !MinecraftAssetImporter.lastReport.cancelled ? Colors.error : Colors.banned
                    }
                }
            }
            SettingsCard {
                title: "当前资源 · " + root.currentVersion
                description: root.catalogSummary
                contentHeight: itemForm.height
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
                        Controls.ScrollBar.vertical: Controls.ScrollBar {}
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
                        SettingsActionButton { text: "添加物品"; enabled: !root.busy; onClicked: root.saveCustomItem() }
                    }
                    XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.error; xcText: root.formError; visible: root.formError.length > 0 }
                }
            }
        }
    }
    Controls.Popup {
        id: versionPicker
        parent: Controls.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(480, parent ? parent.width - 40 : 480)
        height: Math.min(560, parent ? parent.height - 40 : 560)
        padding: 18
        modal: true
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        background: Rectangle { color: Colors.foreground; radius: 12; border.width: 1; border.color: Colors.changeA(Colors.border, 0.4) }
        contentItem: Column {
            spacing: 10
            XCText { xcText: "选择 Minecraft 版本"; onCenter: false; xcFontSize: 18 }
            XCTextField { id: versionSearch; width: parent.width; placeholderText: "搜索版本，例如 1.13" }
            Flow {
                width: parent.width; spacing: 12
                XCCheckBox { text: "显示测试版"; height: 32; checked: root.showSnapshots; onToggled: root.showSnapshots = checked }
                SettingsActionButton { text: MinecraftAssetImporter.loadingVersions ? "正在刷新…" : "刷新官方列表"; enabled: !MinecraftAssetImporter.loadingVersions; onClicked: MinecraftAssetImporter.refreshVersions(root.itemsRootPath) }
            }
            XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned; xcText: MinecraftAssetImporter.versionsStatus }
            ListView {
                id: versionsList; width: parent.width
                height: Math.max(100, versionPicker.availableHeight - y - 42)
                clip: true; spacing: 3; model: root.pickerVersions
                Controls.ScrollBar.vertical: Controls.ScrollBar {}
                delegate: SettingsActionButton {
                    required property var modelData
                    objectName: "minecraftVersionChoice_" + modelData.id
                    width: versionsList.width - 12; text: modelData.label
                    onClicked: { versionField.text = modelData.id; jarField.text = ""; versionPicker.close() }
                }
            }
            SettingsActionButton { text: "关闭"; onClicked: versionPicker.close() }
        }
    }
}
