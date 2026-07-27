pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true

    property int currentSection: 0
    property var sectionNames: ["外观", "动画", "商店模板", "物品信息"]
    property var accentChoices: ["#00aaff", "#7c5cff", "#e85d9e", "#17b890", "#f2a541"]
    property var colorChoices: ["#1b1d27", "#202b38", "#2b2238", "#162d2d", "#33251d"]
    property var templates: []
    property var itemMappings: []
    property var filteredItems: []
    property var customMappings: []
    property string itemSearch: ""
    property string customItemsPath: ""

    XCFile { id: xcFile }

    function chooseTheme(color) {
        Global.themeColor = color
        Colors.border = color
        Global.saveSettings()
    }

    function loadTemplates() {
        var text = xcFile.read("templates.json")
        if (!text.length)
            return
        try {
            var data = JSON.parse(text)
            templates = data.Intros ? data.Intros : []
        } catch (error) {
            templates = []
        }
    }

    function loadItemMappings() {
        var raw = xcFile.read(":/assets/minecraft/items/ForeverIds-main/items/items.min.json")
        var original = []
        try { original = JSON.parse(raw) } catch (error) { original = [] }

        customItemsPath = APP_DIRPATH + "/item-mappings.json"
        var saved = xcFile.read(customItemsPath)
        try { customMappings = saved.length ? JSON.parse(saved) : [] } catch (error) { customMappings = [] }

        var customById = {}
        for (var i = 0; i < customMappings.length; ++i)
            customById[customMappings[i].itemId] = customMappings[i]

        var mappings = []
        for (var j = 0; j < original.length; ++j) {
            var vanilla = original[j]
            var override = customById[vanilla.name]
            mappings.push({
                itemId: vanilla.name,
                texturePath: override ? override.texturePath : "",
                builtIn: true,
                numericId: vanilla.id
            })
        }
        for (var k = 0; k < customMappings.length; ++k) {
            if (!customMappings[k].itemId.startsWith("minecraft:"))
                mappings.push({ itemId: customMappings[k].itemId, texturePath: customMappings[k].texturePath, builtIn: false, numericId: "自定义" })
        }
        itemMappings = mappings
        filterItems()
    }

    function filterItems() {
        var keyword = itemSearch.trim().toLowerCase()
        if (!keyword.length) {
            filteredItems = itemMappings
            return
        }

        function matchScore(entry) {
            var id = entry.itemId.toLowerCase()
            var path = id.indexOf(":") >= 0 ? id.split(":")[1] : id
            var texture = entry.texturePath.toLowerCase()

            if (id === keyword) return 0
            if (path === keyword) return 1
            if (id.indexOf(keyword) === 0) return 2
            if (path.indexOf(keyword) === 0) return 3

            var words = path.split("_")
            for (var wordIndex = 0; wordIndex < words.length; ++wordIndex)
                if (words[wordIndex].indexOf(keyword) === 0)
                    return 4

            var idPosition = id.indexOf(keyword)
            if (idPosition >= 0) return 10 + idPosition

            var texturePosition = texture.indexOf(keyword)
            return texturePosition >= 0 ? 100 + texturePosition : -1
        }

        var matches = []
        for (var i = 0; i < itemMappings.length; ++i) {
            var entry = itemMappings[i]
            var score = matchScore(entry)
            if (score >= 0)
                matches.push({ entry: entry, score: score })
        }
        matches.sort(function(left, right) {
            if (left.score !== right.score)
                return left.score - right.score
            if (left.entry.itemId.length !== right.entry.itemId.length)
                return left.entry.itemId.length - right.entry.itemId.length
            return left.entry.itemId.localeCompare(right.entry.itemId)
        })
        filteredItems = matches.map(function(match) { return match.entry })
    }

    function saveCustomMapping() {
        var id = customIdInput.text.trim()
        var texture = customTextureInput.text.trim()
        if (!id.length)
            return
        var replaced = false
        for (var i = 0; i < customMappings.length; ++i) {
            if (customMappings[i].itemId === id) {
                customMappings[i].texturePath = texture
                replaced = true
                break
            }
        }
        if (!replaced)
            customMappings.push({ itemId: id, texturePath: texture })
        customMappings = customMappings
        xcFile.write(customItemsPath, JSON.stringify(customMappings))
        customIdInput.text = ""
        customTextureInput.text = ""
        loadItemMappings()
    }

    function removeCustomMapping(itemId) {
        var next = []
        for (var i = 0; i < customMappings.length; ++i)
            if (customMappings[i].itemId !== itemId)
                next.push(customMappings[i])
        customMappings = next
        xcFile.write(customItemsPath, JSON.stringify(customMappings))
        loadItemMappings()
    }

    Component.onCompleted: {
        loadTemplates()
        loadItemMappings()
    }

    XCFileDialog {
        id: imageFileDialog
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp)", "All files (*)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (dialogID === "background") {
                Global.backgroundImage = path
                Global.backgroundMode = "image"
                Global.saveSettings()
            } else if (dialogID === "itemTexture") {
                customTextureInput.text = path
            }
        }
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.96)

        Column {
            id: nav
            x: 16
            y: 16
            width: 144
            height: parent.height - 32
            spacing: 4

            TextButton {
                width: nav.width
                height: 32
                radius: 6
                text: "← 返回"
                textSize: 13
                widthBorderSize: 9
                buttonColor: Colors.pressed
                onClicked: root.pageEvent("Settings.back", {})
            }
            Item { width: 1; height: 8 }
            XCText { xcText: "设置"; onCenter: false; xcFontSize: 24 }
            XCText { xcText: "界面与本地资源"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }

            Item { width: 1; height: 18 }
            Repeater {
                model: root.sectionNames
                delegate: SettingsNavButton {
                    required property int index
                    required property string modelData
                    text: modelData
                    selected: root.currentSection === index
                    onClicked: root.currentSection = index
                }
            }
            Item { width: 1; height: Math.max(1, nav.height - y - 64) }
            XCText { width: parent.width; xcText: "这些设置只影响编辑器的显示效果，不会写入数据包。"; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
        }

        Rectangle { x: 176; width: 1; anchors.top: parent.top; anchors.bottom: parent.bottom; color: Colors.changeA(Colors.text, 0.12) }

        Item {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 28
            anchors.leftMargin: 204

            Item {
                anchors.fill: parent
                visible: root.currentSection === 0
                Column {
                    width: parent.width
                    spacing: 20
                    SettingsPageHeader { title: "外观"; subtitle: "修改强调色、窗口底色和背景效果。"; width: parent.width }
                    SettingsCard {
                        title: "主题色"
                        contentHeight: 28
                        Row { anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Repeater { model: root.accentChoices; delegate: Rectangle { required property string modelData; width: 28; height: 28; radius: 14; color: modelData; border.width: Global.themeColor === modelData ? 3 : 0; border.color: Colors.text
                                MouseArea { anchors.fill: parent; onClicked: root.chooseTheme(parent.modelData) }
                            } }
                        }
                    }
                    SettingsCard {
                        title: "背景"
                        contentHeight: 142
                        Column { anchors.fill: parent; spacing: 12
                            Row { spacing: 8
                                Repeater { model: ["纯色", "图片", "图片 + 高斯模糊", "流光渐变"]; delegate: TextButton { required property int index; required property string modelData; text: modelData; height: 32; radius: 6; textSize: 13; widthBorderSize: 9; buttonColor: Colors.pressed; pressedColor: Colors.changeA(Colors.border, 0.45); btnSelected: ["color", "image", "imageBlur", "flow"][index] === Global.backgroundMode
                                    onClicked: {
                                        Global.backgroundMode = ["color", "image", "imageBlur", "flow"][index]
                                        Global.saveSettings()
                                    }
                                } }
                            }
                            Row { spacing: 10; visible: Global.backgroundMode === "color"
                                XCText { xcText: "纯色预设"; onCenter: false; xcFontSize: 13; boldFont: false; width: 70 }
                                Repeater { model: root.colorChoices; delegate: Rectangle { required property string modelData; width: 25; height: 25; radius: 4; color: modelData; border.width: Global.backgroundColor === modelData ? 2 : 0; border.color: Colors.text
                                    MouseArea { anchors.fill: parent; onClicked: { Global.backgroundColor = parent.modelData; Global.saveSettings() } }
                                } }
                            }
                            Row { spacing: 10; visible: Global.backgroundMode === "image" || Global.backgroundMode === "imageBlur"
                                TextButton { text: "选择图片"; height: 32; radius: 6; textSize: 13; widthBorderSize: 9; buttonColor: Colors.pressed; onClicked: imageFileDialog.openXC(false, "background") }
                                XCText { width: 430; xcText: Global.backgroundImage.length ? Global.backgroundImage : "未选择图片，使用内置背景预览"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                            }
                            Row { spacing: 10; visible: Global.backgroundMode === "imageBlur"
                                XCText { xcText: "模糊强度"; onCenter: false; xcFontSize: 13; boldFont: false; width: 70 }
                                Slider { width: 200; from: 0; to: 1; value: Global.backgroundBlur; onMoved: { Global.backgroundBlur = value; Global.saveSettings() } }
                            }
                            XCText { visible: Global.backgroundMode === "flow"; xcText: "流光由渐变色块和高斯模糊构成，速度受“动画”设置控制。"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: root.currentSection === 1
                Column { width: parent.width; spacing: 20
                    SettingsPageHeader { title: "动画"; subtitle: "控制背景流光及后续界面动效的全局倍速。"; width: parent.width }
                    SettingsCard { title: "动画倍速"; contentHeight: 64
                        Column { anchors.fill: parent; spacing: 8
                            Row { spacing: 14
                                XCText { xcText: "当前速度"; onCenter: false; xcFontSize: 14; width: 92 }
                                XCText { xcText: Global.animationSpeed.toFixed(2) + "×"; onCenter: false; xcFontSize: 16; textColor: Colors.border }
                            }
                            Slider { width: Math.min(420, parent.width - 24); from: 0.25; to: 3; stepSize: 0.05; value: Global.animationSpeed; onMoved: { Global.animationSpeed = value; Global.saveSettings() } }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: root.currentSection === 2
                Column { anchors.fill: parent; spacing: 12
                    SettingsPageHeader { title: "商店模板"; width: parent.width }
                    Row { width: parent.width
                        XCText { xcText: root.templates.length + " 个模板类型"; onCenter: false; xcFontSize: 13; boldFont: false; textColor: Colors.banned }
                        Item { width: 12; height: 1 }
                        TextButton { text: "重新读取本地缓存"; height: 28; radius: 5; textSize: 12; widthBorderSize: 8; buttonColor: Colors.pressed; onClicked: root.loadTemplates() }
                    }
                    XCText { visible: !root.templates.length; xcText: "尚未找到模板缓存。请在“创建项目”页面点击“获取”同步模板；同步后这里会按模板类型汇总其所有支持的 Minecraft 版本。"; onCenter: false; xcWrapMode: true; width: parent.width - 12; xcFontSize: 13; boldFont: false; textColor: Colors.banned }
                    ListView { width: parent.width; height: parent.height - y; clip: true; model: root.templates; spacing: 8
                        delegate: Rectangle { id: templateDelegate; required property var modelData; width: ListView.view.width; height: 88; radius: 9; color: Colors.changeA(Colors.foreground, 0.65)
                            Column { anchors.fill: parent; anchors.margins: 14; spacing: 8
                                XCText { xcText: templateDelegate.modelData.id; onCenter: false; xcFontSize: 16 }
                                Row { spacing: 6
                                    Repeater { model: templateDelegate.modelData.versions; delegate: Rectangle { id: versionDelegate; required property string modelData; width: versionText.width + 14; height: 22; radius: 11; color: Colors.changeA(Colors.border, 0.25)
                                        XCText { id: versionText; xcText: versionDelegate.modelData; xcFontSize: 12 }
                                    } }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: root.currentSection === 3
                Column { anchors.fill: parent; spacing: 12
                    SettingsPageHeader { title: "Minecraft 物品信息"; subtitle: "内置原版物品 ID 清单；映射仅供编辑器显示，不会改变生成的数据包。"; width: parent.width }
                    SettingsCard { title: "添加或覆盖映射"; contentHeight: 54
                        Row { anchors.fill: parent; spacing: 10
                            Column { width: parent.width * 0.32; spacing: 5
                                XCText { xcText: "物品 ID / 模组 ID"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                                XCTextField { id: customIdInput; width: parent.width; placeholderText: "examplemod:machine" }
                            }
                            Column { width: parent.width * 0.42; spacing: 5
                                XCText { xcText: "贴图路径"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                                XCTextField { id: customTextureInput; width: parent.width; placeholderText: "可选：PNG 文件或资源路径" }
                            }
                            Column { width: parent.width * 0.18; spacing: 5
                                XCText { xcText: "操作"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                                Row { spacing: 5
                                    TextButton { text: "选贴图"; height: 32; radius: 5; textSize: 12; widthBorderSize: 8; buttonColor: Colors.pressed; onClicked: imageFileDialog.openXC(false, "itemTexture") }
                                    TextButton { text: "保存"; height: 32; radius: 5; textSize: 12; widthBorderSize: 8; buttonColor: Colors.changeA(Colors.border, 0.7); onClicked: root.saveCustomMapping() }
                                }
                            }
                        }
                    }
                    XCTextField { id: itemSearchField; width: parent.width; placeholderText: "搜索 ID 或贴图路径（共 " + root.itemMappings.length + " 条）"; onTextChanged: { root.itemSearch = text; root.filterItems() } }
                    Row { width: parent.width; height: 20
                        XCText { width: parent.width * 0.54; xcText: "物品 ID"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                        XCText { width: parent.width * 0.31; xcText: "贴图对应关系"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                        XCText { xcText: "来源"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                    }
                    Rectangle { width: parent.width; height: parent.height - y; radius: 8; clip: true; color: Colors.transparent
                        ListView { anchors.fill: parent; anchors.margins: 1; clip: true; model: root.filteredItems; spacing: 1
                            delegate: Rectangle { id: itemDelegate; required property var modelData; width: ListView.view.width; height: 38; color: Colors.transparent
                            XCText { x: 8; width: parent.width * 0.52; xcText: itemDelegate.modelData.itemId; onCenter: false; xcFontSize: 13; boldFont: false }
                            XCText { x: parent.width * 0.54; width: parent.width * 0.29; xcText: itemDelegate.modelData.texturePath.length ? itemDelegate.modelData.texturePath : "待处理 / 未配置"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: itemDelegate.modelData.texturePath.length ? Colors.text : Colors.banned }
                            XCText { x: parent.width * 0.85; width: parent.width * 0.09; xcText: itemDelegate.modelData.builtIn ? "原版" : "自定义"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                            TextButton { visible: !itemDelegate.modelData.builtIn; text: "删除"; x: parent.width - width - 4; y: 6; height: 26; radius: 4; textSize: 11; widthBorderSize: 7; buttonColor: Colors.transparent; pressedColor: "#884d4d"; onClicked: root.removeCustomMapping(itemDelegate.modelData.itemId) }
                            }
                        }
                    }
                }
            }
        }
    }
}
