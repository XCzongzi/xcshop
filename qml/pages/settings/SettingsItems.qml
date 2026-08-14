import QtQuick
import QtQuick.Dialogs
import xcshop

Item {
    id: root
    property var itemMappings: []
    property var filteredItems: []
    property var customMappings: []
    property string itemSearch: ""
    property string customItemsPath: ""

    XCFile { id: xcFile }
    function loadItemMappings() {
        var raw = xcFile.read(":/assets/minecraft/items/ForeverIds-main/items/items.min.json")
        var original = []
        try { original = JSON.parse(raw) } catch (error) { original = [] }
        customItemsPath = APP_DIRPATH + "/item-mappings.json"
        var saved = xcFile.read(customItemsPath)
        try { customMappings = saved.length ? JSON.parse(saved) : [] } catch (error) { customMappings = [] }
        var customById = {}
        for (var i = 0; i < customMappings.length; ++i) customById[customMappings[i].itemId] = customMappings[i]
        var mappings = []
        for (var j = 0; j < original.length; ++j) {
            var vanilla = original[j]
            var override = customById[vanilla.name]
            mappings.push({ itemId: vanilla.name, texturePath: override ? override.texturePath : "", builtIn: true, numericId: vanilla.id })
        }
        for (var k = 0; k < customMappings.length; ++k)
            if (!customMappings[k].itemId.startsWith("minecraft:")) mappings.push({ itemId: customMappings[k].itemId, texturePath: customMappings[k].texturePath, builtIn: false, numericId: "自定义" })
        itemMappings = mappings
        filterItems()
    }
    function builtInItemTexture(itemId) { var path = itemId.indexOf(":") >= 0 ? itemId.split(":")[1] : itemId; return "qrc:/assets/minecraft/items/minecraft-assets-26.2/textures/item/" + path + ".png" }
    function builtInBlockTexture(itemId) { var path = itemId.indexOf(":") >= 0 ? itemId.split(":")[1] : itemId; return "qrc:/assets/minecraft/items/minecraft-assets-26.2/textures/block/" + path + ".png" }
    function filterItems() {
        var keyword = itemSearch.trim().toLowerCase()
        if (!keyword.length) { filteredItems = itemMappings; return }
        function matchScore(entry) {
            var id = entry.itemId.toLowerCase(), path = id.indexOf(":") >= 0 ? id.split(":")[1] : id, texture = entry.texturePath.toLowerCase()
            if (id === keyword) return 0
            if (path === keyword) return 1
            if (id.indexOf(keyword) === 0) return 2
            if (path.indexOf(keyword) === 0) return 3
            var words = path.split("_")
            for (var wordIndex = 0; wordIndex < words.length; ++wordIndex) if (words[wordIndex].indexOf(keyword) === 0) return 4
            var idPosition = id.indexOf(keyword)
            if (idPosition >= 0) return 10 + idPosition
            var texturePosition = texture.indexOf(keyword)
            return texturePosition >= 0 ? 100 + texturePosition : -1
        }
        var matches = []
        for (var i = 0; i < itemMappings.length; ++i) { var entry = itemMappings[i], score = matchScore(entry); if (score >= 0) matches.push({ entry: entry, score: score }) }
        matches.sort(function(left, right) { if (left.score !== right.score) return left.score - right.score; if (left.entry.itemId.length !== right.entry.itemId.length) return left.entry.itemId.length - right.entry.itemId.length; return left.entry.itemId.localeCompare(right.entry.itemId) })
        filteredItems = matches.map(function(match) { return match.entry })
    }
    function saveCustomMapping() {
        var id = customIdInput.text.trim(), texture = customTextureInput.text.trim()
        if (!id.length) return
        var replaced = false
        for (var i = 0; i < customMappings.length; ++i) if (customMappings[i].itemId === id) { customMappings[i].texturePath = texture; replaced = true; break }
        if (!replaced) customMappings.push({ itemId: id, texturePath: texture })
        customMappings = customMappings
        xcFile.write(customItemsPath, JSON.stringify(customMappings))
        customIdInput.text = ""; customTextureInput.text = ""; loadItemMappings()
    }
    function removeCustomMapping(itemId) {
        var next = []
        for (var i = 0; i < customMappings.length; ++i) if (customMappings[i].itemId !== itemId) next.push(customMappings[i])
        customMappings = next; xcFile.write(customItemsPath, JSON.stringify(customMappings)); loadItemMappings()
    }
    Component.onCompleted: loadItemMappings()

    XCFileDialog { id: imageFileDialog; nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp)", "All files (*)"]; onAccepted: customTextureInput.text = selectedFile.toString() }

    Column {
        anchors.fill: parent
        spacing: 12
        SettingsPageHeader { title: "Minecraft 物品信息"; subtitle: "内置原版物品 ID 清单；映射仅供编辑器显示，不会改变生成的数据包。"; width: parent.width }
        ContentBar {
            id: mappingEditor
            width: parent.width
            expanded: true
            title: "添加或覆盖映射"
            subtitle: "为原版物品覆盖贴图，或添加模组物品的本地显示映射。"
            contentHeight: mappingFields.y + mappingFields.height + 16
            Row {
                id: mappingFields
                x: 16; y: 70
                width: parent.width - 32
                spacing: 10
                Column {
                    width: parent.width * 0.32; spacing: 5
                    XCText { xcText: "物品 ID / 模组 ID"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    XCTextField { id: customIdInput; width: parent.width; placeholderText: "examplemod:machine" }
                }
                Column {
                    width: parent.width * 0.42; spacing: 5
                    XCText { xcText: "贴图路径"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    XCTextField { id: customTextureInput; width: parent.width; placeholderText: "可选：PNG 文件或资源路径" }
                }
                Column {
                    width: parent.width * 0.18; spacing: 5
                    XCText { xcText: "操作"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    Row {
                        spacing: 5
                        TextButton { text: "选贴图"; height: 32; radius: 5; textSize: 12; widthBorderSize: 8; buttonColor: Colors.pressed; onClicked: imageFileDialog.openXC(false, "itemTexture") }
                        TextButton { text: "保存"; height: 32; radius: 5; textSize: 12; widthBorderSize: 8; buttonColor: Colors.changeA(Colors.border, 0.7); onClicked: root.saveCustomMapping() }
                    }
                }
            }
        }
        ContentBar {
            id: mappingListBar
            width: parent.width
            expanded: true
            title: "物品映射"
            subtitle: "共 " + root.itemMappings.length + " 条，支持按 ID 或贴图路径搜索。"
            contentHeight: parent.height - y
            XCTextField { id: itemSearchField; x: 16; y: 70; width: parent.width - 32; placeholderText: "搜索 ID 或贴图路径"; onTextChanged: { root.itemSearch = text; root.filterItems() } }
            Row {
                x: 16; y: 112; width: parent.width - 32; height: 20
                XCText { width: 42; xcText: "贴图"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { width: parent.width * 0.52 - 42; xcText: "物品 ID"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                Item { width: parent.width * 0.02; height: 1 }
                XCText { width: parent.width * 0.31; xcText: "贴图对应关系"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                XCText { xcText: "来源"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
            }
            ListView {
                x: 16; y: 136; width: parent.width - 32; height: parent.height - y - 12
                clip: true; model: root.filteredItems; spacing: 1
                delegate: Rectangle {
                    id: itemDelegate
                    required property var modelData
                    width: ListView.view.width; height: 38; color: Colors.transparent
                    property bool usingBlockTexture: false
                    property string iconSource: itemDelegate.modelData.texturePath.length ? itemDelegate.modelData.texturePath : root.builtInItemTexture(itemDelegate.modelData.itemId)
                    Rectangle {
                        x: 7; y: 5; width: 28; height: 28; radius: 4; color: Colors.changeA(Colors.foreground, 0.72)
                        Image { anchors.centerIn: parent; width: 24; height: 24; source: itemDelegate.iconSource; fillMode: Image.PreserveAspectFit; smooth: false; mipmap: false; asynchronous: true; onStatusChanged: { if (status === Image.Error && !itemDelegate.modelData.texturePath.length && !itemDelegate.usingBlockTexture) { itemDelegate.usingBlockTexture = true; itemDelegate.iconSource = root.builtInBlockTexture(itemDelegate.modelData.itemId) } } }
                    }
                    XCText { x: 42; width: parent.width * 0.52 - 42; xcText: itemDelegate.modelData.itemId; onCenter: false; xcFontSize: 13; boldFont: false }
                    XCText { x: parent.width * 0.54; width: parent.width * 0.29; xcText: itemDelegate.modelData.texturePath.length ? itemDelegate.modelData.texturePath : "待处理 / 未配置"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: itemDelegate.modelData.texturePath.length ? Colors.text : Colors.banned; elide: Text.ElideMiddle }
                    XCText { x: parent.width * 0.85; width: parent.width * 0.09; xcText: itemDelegate.modelData.builtIn ? "原版" : "自定义"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    TextButton { visible: !itemDelegate.modelData.builtIn; text: "删除"; x: parent.width - width - 4; y: 6; height: 26; radius: 4; textSize: 11; widthBorderSize: 7; buttonColor: Colors.transparent; pressedColor: "#884d4d"; onClicked: root.removeCustomMapping(itemDelegate.modelData.itemId) }
                }
            }
        }
    }
}
