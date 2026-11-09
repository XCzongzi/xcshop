pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BasePage {
    id: root
    objectName: "initializationPage"
    x: 0
    color: Colors.transparent
    fullScreen: true
    usePageScrollBar: false
    animateEntrance: false
    property real initialEntranceOffset: 10
    transform: Translate { y: root.initialEntranceOffset }

    // welcome, update, theme, templates, items
    property string step: "welcome"
    property string displayedStep: "welcome"
    onStepChanged: stepMotion.changeTo(step)
    property bool checkComplete: false
    property bool canSkipCheck: false
    property bool updateCheckSkipped: false
    property string errorText: ""
    property bool showImport: false
    property var mappedItems: []
    property string mappingVersion: ""
    property int missingIcons: 0
    readonly property string itemsRoot: APP_DIRPATH + "/assets/minecraft/items"
    readonly property bool busy: BuildKits.acquiring || MinecraftAssetImporter.importing
    readonly property bool configuring: displayedStep === "theme" || displayedStep === "templates" || displayedStep === "items"
    readonly property int stepIndex: ["theme", "templates", "items"].indexOf(displayedStep)

    XCFile { id: files }
    function readJson(path, fallback) {
        try { return JSON.parse(files.read(path)) }
        catch (error) { return fallback }
    }
    function loadMappings() {
        Global.reloadMinecraftResources()
        var catalog = Global.minecraftPackPath.length
                ? readJson(Global.minecraftPackPath + "/catalog.json", null) : null
        var entries = catalog && catalog.schemaVersion === 2 && Array.isArray(catalog.items)
                ? catalog.items : []
        mappingVersion = catalog ? String(catalog.gameVersion || "") : ""
        if (!Array.isArray(entries)) entries = []
        var result = []
        var seen = ({})
        var missing = 0
        function append(id, status) {
            if (typeof id !== "string" || id === "minecraft:air" || seen[id]) return
            var texture = Global.getItemTexturePath(id)
            if (!texture.length) return
            var available = status !== "missing" && files.exists(texture)
            seen[id] = true
            if (!available) missing++
            result.push({name: id, source: available ? "file:///" + texture.replace(/\\/g, "/")
                         + "?revision=" + Global.minecraftIconRevision : "qrc:/assets/gui/element/Item.png"})
        }
        for (var item of entries) if (item) append(item.name, item.iconStatus)
        var custom = readJson(itemsRoot + "/custom-items.json", [])
        if (Array.isArray(custom)) for (var entry of custom) if (entry) append(entry.itemId, "custom")
        mappedItems = result
        missingIcons = missing
    }
    function begin() {
        if (!checkComplete || stepMotion.running) return
        step = !updateCheckSkipped && Updates.updateAvailable ? "update" : "theme"
    }
    function skipUpdateCheck() {
        if (!canSkipCheck || checkComplete) return
        updateCheckSkipped = true
        checkComplete = true
        Updates.cancel()
    }
    function next() {
        if (busy || stepMotion.running) return
        errorText = ""
        if (step === "update") {
            Updates.dismissVersion(Updates.latestVersion)
            step = "theme"
        } else if (step === "theme") {
            if (!themePicker.selectedTheme.length) return
            themePicker.finishPreview()
            Global.saveSettings()
            BuildKits.refresh()
            step = "templates"
        } else if (step === "templates") {
            loadMappings()
            step = "items"
        } else if (step === "items") {
            Global.initializationCompleted = true
            if (!Global.saveSettings()) {
                Global.initializationCompleted = false
                errorText = "无法保存设置，请检查软件目录的写入权限。"
                return
            }
            pageEvent("Initialize.finished", {})
        }
    }
    function back() {
        if (busy || stepMotion.running) return
        errorText = ""
        step = step === "items" ? "templates" : "theme"
    }
    function importGame(path, javaPath) {
        errorText = ""
        var saved = readJson(itemsRoot + "/import-settings.json", {})
        var options = {itemsRoot: itemsRoot, source: "local",
            sourcePath: path.trim(), javaPath: javaPath.trim(),
            librariesPath: saved.librariesPath || "", allowNetwork: true, generator: "client"}
        if (MinecraftAssetImporter.startImport(options)) {
            files.writeAtomic(itemsRoot + "/import-settings.json", JSON.stringify(Object.assign({}, saved, {
                source: "local", sourcePath: options.sourcePath, javaPath: options.javaPath, allowNetwork: true
            })))
        }
    }
    Component.onCompleted: {
        initialEntrance.start()
        Qt.callLater(function() { Updates.check() })
    }
    ParallelAnimation {
        id: initialEntrance
        NumberAnimation {
            target: root; property: "opacity"; from: 0; to: 1
            duration: 180 / Math.max(0.1, Global.animationSpeed)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "initialEntranceOffset"; from: 10; to: 0
            duration: 180 / Math.max(0.1, Global.animationSpeed)
            easing.type: Easing.OutCubic
        }
    }
    Timer {
        interval: 2000
        running: Updates.checking && !root.checkComplete && root.displayedStep === "welcome"
        onTriggered: root.canSkipCheck = true
    }
    Connections {
        target: Updates
        function onCheckFinished() { root.checkComplete = true }
    }
    Connections {
        target: MinecraftAssetImporter
        function onImportFinished(report) {
            if (report.ok) { root.loadMappings(); root.showImport = false }
            else root.errorText = report.cancelled ? "已取消导入" : (report.message || MinecraftAssetImporter.status)
        }
    }

    AmbientBackground {
        parent: root.backgroundHost || root
        anchors.fill: parent
        animated: true
        opacity: root.opacity
    }

    Item {
        id: transitionContent
        anchors.fill: parent
        opacity: stepMotion.contentOpacity
        transform: Translate { y: stepMotion.contentOffset }

        Item {
            anchors.fill: parent
            visible: root.displayedStep === "welcome"
            Column {
                z: 1
                anchors.centerIn: parent
                width: parent.width - 80
                spacing: 18
                XCText { width: parent.width; onCenter: false; horizontalAlignment: Text.AlignHCenter; xcText: "欢迎使用 XCShop"; xcFontSize: 36 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    XCText {
                        objectName: "initializationWelcomeStatus"
                        onCenter: false
                        xcText: root.checkComplete ? "点击任意位置开始" : "正在检查更新"
                        xcFontSize: 14; boldFont: false; textColor: Colors.banned
                    }
                    XCText {
                        objectName: "initializationSkipUpdateCheck"
                        visible: root.canSkipCheck && !root.checkComplete
                        onCenter: false; xcText: "跳过"; xcFontSize: 14; boldFont: false
                        textColor: skipPointer.containsMouse ? Colors.text : Colors.accentText
                        underlineFont: skipPointer.containsMouse
                        MouseArea {
                            id: skipPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.skipUpdateCheck()
                        }
                    }
                }
            }
            MouseArea {
                objectName: "initializationWelcomeAction"
                anchors.fill: parent
                enabled: root.checkComplete
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.begin()
            }
        }

        Item {
            id: wizard
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 56
            anchors.bottom: parent.bottom; anchors.bottomMargin: 28
            width: root.displayedStep === "theme" ? parent.width - 80 : Math.min(720, parent.width - 80)
            visible: root.displayedStep !== "welcome"

            Row {
                id: steps
                height: 24; spacing: 30
                visible: root.configuring && root.displayedStep !== "theme"
                Repeater {
                    model: ["主题", "模板", "物品映射"]
                    delegate: XCText {
                        required property int index
                        required property string modelData
                        onCenter: false; xcText: modelData; xcFontSize: 12
                        boldFont: root.stepIndex === index
                        textColor: root.stepIndex === index ? Colors.accentText : Colors.banned
                    }
                }
            }
            XCText {
                id: heading
                visible: root.displayedStep !== "theme"
                y: root.configuring ? 38 : 12
                width: parent.width; onCenter: false; xcFontSize: 26
                xcText: root.displayedStep === "update" ? "发现新版本 v" + Updates.latestVersion
                      : root.displayedStep === "theme" ? "选择喜欢的主题"
                      : root.displayedStep === "templates" ? "检查模板" : "检查物品映射"
            }
            XCScrollView {
                id: scroll
                visible: root.displayedStep !== "theme"
                anchors.top: heading.bottom; anchors.topMargin: 22
                anchors.bottom: feedback.top; anchors.bottomMargin: 16
                width: parent.width
                contentHeight: body.height
                Loader {
                    id: body
                    active: wizard.visible && root.displayedStep !== "theme"
                    width: scroll.availableWidth
                    sourceComponent: root.displayedStep === "update" ? updateContent
                                   : root.displayedStep === "templates" ? templateContent : itemContent
                    onLoaded: scroll.contentItem.contentY = 0
                }
            }
            XCText {
                objectName: "initializationBackgroundHint"
                anchors.bottom: navigation.top; anchors.bottomMargin: 12
                width: parent.width
                visible: root.displayedStep === "theme" && nextButton.visible && nextButton.enabled
                onCenter: false; horizontalAlignment: Text.AlignRight
                xcWrapMode: true; boldFont: false; xcFontSize: 12
                textColor: Colors.banned
                xcText: "稍后可在设置页中启用背景图片"
            }
            Item {
                id: feedback
                anchors.bottom: navigation.top; anchors.bottomMargin: root.errorText.length ? 12 : 0
                width: parent.width; height: errorMessage.visible ? errorMessage.implicitHeight : 0
                XCText {
                    id: errorMessage
                    width: parent.width; visible: root.errorText.length > 0
                    onCenter: false; xcWrapMode: true; boldFont: false; xcFontSize: 12
                    elide: Text.ElideNone; textColor: Colors.error; xcText: root.errorText
                }
            }
            Item {
                id: navigation
                anchors.bottom: parent.bottom
                width: parent.width; height: 36
                ActionButton {
                    objectName: "initializationBack"
                    visible: root.displayedStep === "templates" || root.displayedStep === "items"
                    enabled: !root.busy; text: "上一步"; onClicked: root.back()
                }
                Row {
                    anchors.right: parent.right; spacing: 10
                    ActionButton {
                        objectName: "initializationViewUpdate"
                        visible: root.displayedStep === "update"; text: "查看更新"; primary: true
                        onClicked: {
                            if (!Qt.openUrlExternally(Updates.releaseUrl)) root.errorText = "无法打开更新页面，请稍后在关于页面重试。"
                        }
                    }
                    ActionButton {
                        id: nextButton
                        objectName: "initializationNext"
                        visible: root.displayedStep !== "theme" || themePicker.expanded
                        text: root.displayedStep === "items" ? "完成" : root.displayedStep === "update" ? "继续设置" : "下一步"
                        primary: root.displayedStep !== "update"
                        enabled: !root.busy && (root.displayedStep !== "theme" || themePicker.selectedTheme.length > 0)
                        onClicked: root.next()
                    }
                }
            }
        }

        InitializationThemePicker {
            id: themePicker
            anchors.fill: parent
            visible: root.displayedStep === "theme"
        }
    }
    PageTransition {
        id: stepMotion
        objectName: "initializationStepTransition"
        currentValue: "welcome"
        exitOffset: root.displayedStep === "welcome" || root.displayedStep === "update" ? 0 : -6
        exitDuration: root.displayedStep === "welcome" || root.displayedStep === "update" ? 500 : 110
        enterDuration: root.displayedStep === "welcome" || root.displayedStep === "update" ? 500 : 180
        onCommit: function(value) { root.displayedStep = value }
    }

    Component {
        id: updateContent
        Column {
            spacing: 16
            XCText { width: parent.width; onCenter: false; xcText: "当前版本 v" + Qt.application.version; xcFontSize: 13; boldFont: false; textColor: Colors.banned }
            XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcText: Updates.releaseNotes || "新版本已发布。"; textFormat: Text.PlainText; xcFontSize: 14; boldFont: false }
        }
    }
    Component {
        id: templateContent
        Column {
            id: templates
            spacing: 12
            Row {
                spacing: 12
                XCText { height: 34; verticalAlignment: Text.AlignVCenter; onCenter: false; xcText: "已包含 " + BuildKits.templates.length + " 个模板"; xcFontSize: 13; boldFont: false; textColor: Colors.banned }
                ActionButton {
                    objectName: "initializationDownloadTemplates"
                    text: BuildKits.downloadCooldownSeconds > 0 ? "在线获取（" + BuildKits.downloadCooldownSeconds + " 秒）" : "在线获取"
                    enabled: !BuildKits.busy && BuildKits.downloadCooldownSeconds === 0
                    onClicked: BuildKits.acquire()
                }
                ActionButton { visible: BuildKits.acquiring; text: "取消"; onClicked: BuildKits.cancelAcquisition() }
            }
            XCText { visible: BuildKits.acquisitionStatus.length > 0; width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; xcText: BuildKits.acquisitionStatus }
            Rectangle {
                width: parent.width; height: 3; radius: 1.5; visible: BuildKits.acquiring
                color: Colors.changeA(Colors.control, 0.5)
                Rectangle { height: parent.height; radius: parent.radius; width: parent.width * Math.max(0.02, BuildKits.acquisitionProgress / 100); color: Colors.accentFill }
            }
            Repeater {
                model: BuildKits.templates
                delegate: Rectangle {
                    id: templateCard
                    required property var modelData
                    width: templates.width; height: templateInfo.height + 28
                    radius: 9; color: Colors.changeA(Colors.card, 0.5)
                    Column {
                        id: templateInfo
                        x: 16; y: 14; width: parent.width - 32; spacing: 8
                        XCText { width: parent.width; onCenter: false; xcText: templateCard.modelData.name; xcFontSize: 14 }
                        XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcText: "游戏版本  " + (templateCard.modelData.versions || []).join("、") + (templateCard.modelData.allowsNewer ? " 及更新版本" : ""); xcFontSize: 12; boldFont: false; textColor: Colors.banned }
                        XCText { visible: !templateCard.modelData.valid || templateCard.modelData.dataVersion !== BuildKits.dataVersion; width: parent.width; onCenter: false; xcText: !templateCard.modelData.valid ? "模板依赖不完整" : "模板数据版本不兼容"; xcFontSize: 12; boldFont: false; textColor: Colors.warning }
                    }
                }
            }
            XCText { visible: !BuildKits.templates.length; width: parent.width; onCenter: false; xcText: "当前包未包含模板，可在线获取或稍后在设置中添加。"; xcFontSize: 13; boldFont: false }
            XCText { visible: BuildKits.issues.length > 0; width: parent.width; onCenter: false; xcWrapMode: true; xcText: BuildKits.issues.join("\n"); xcFontSize: 12; boldFont: false; textColor: Colors.warning }
        }
    }
    Component {
        id: itemContent
        Column {
            id: mappings
            spacing: 16
            Rectangle {
                width: parent.width
                height: versionInfo.height + 28
                visible: root.mappedItems.length > 0
                radius: 9
                color: Colors.changeA(Colors.accentFill, 0.08)
                border.width: 1
                border.color: Colors.changeA(Colors.accentFill, 0.26)
                Column {
                    id: versionInfo
                    x: 14; y: 14; width: parent.width - 28
                    spacing: 6
                    XCText {
                        onCenter: false; xcText: "来源游戏版本"
                        xcFontSize: 12; boldFont: false; textColor: Colors.banned
                    }
                    XCText {
                        objectName: "initializationMappingVersion"
                        width: parent.width; onCenter: false; xcWrapMode: true
                        elide: Text.ElideNone; textFormat: Text.PlainText
                        xcText: root.mappingVersion.length ? "Minecraft Java " + root.mappingVersion : "未记录游戏版本"
                        xcFontSize: 20
                        textColor: root.mappingVersion.length ? Colors.accentText : Colors.banned
                    }
                }
            }
            XCText {
                objectName: "initializationMappingSummary"
                width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 14; boldFont: false
                xcText: root.mappedItems.length ? "共 " + root.mappedItems.length + " 项物品映射"
                      + (root.missingIcons ? "，缺少 " + root.missingIcons + " 个图标" : "")
                      : "当前包未包含物品映射"
            }
            Flow {
                width: parent.width; spacing: 8
                visible: root.mappedItems.length > 0 && !root.showImport
                Repeater {
                    model: root.mappedItems.slice(0, 24)
                    delegate: Rectangle {
                        id: mappingTile
                        required property var modelData
                        width: 44; height: 44; radius: 6; color: Colors.changeA(Colors.card, 0.5)
                        Image { anchors.centerIn: parent; width: 28; height: 28; source: mappingTile.modelData.source; fillMode: Image.PreserveAspectFit; smooth: false }
                        MouseArea { id: itemHover; anchors.fill: parent; hoverEnabled: true }
                        XCToolTip { active: itemHover.containsMouse; text: mappingTile.modelData.name }
                    }
                }
                Rectangle {
                    objectName: "initializationMappingMore"
                    width: 44; height: 44; radius: 6
                    color: Colors.changeA(Colors.card, 0.5)
                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Repeater {
                            model: 3
                            delegate: Rectangle { width: 4; height: 4; radius: 2; color: Colors.banned }
                        }
                    }
                    MouseArea { id: moreHover; anchors.fill: parent; hoverEnabled: true }
                    XCToolTip {
                        active: moreHover.containsMouse
                        text: root.mappedItems.length > 24 ? "另有 " + (root.mappedItems.length - 24) + " 项物品映射" : "物品映射预览"
                    }
                }
            }
            ActionButton {
                objectName: "initializationImportGame"
                visible: !root.showImport; text: "从游戏中重新导入"
                onClicked: root.showImport = true
            }
            Column {
                width: parent.width; spacing: 10; visible: root.showImport
                XCTextField {
                    id: gamePath; objectName: "initializationGamePath"; width: parent.width
                    placeholderText: "游戏目录、版本目录或客户端 JAR"; enabled: !MinecraftAssetImporter.importing
                }
                Row {
                    spacing: 8
                    ActionButton { text: "选择目录"; enabled: !MinecraftAssetImporter.importing; onClicked: gameDialog.openXC("import", gamePath.text) }
                    ActionButton { text: "选择 JAR"; enabled: !MinecraftAssetImporter.importing; onClicked: jarDialog.openXC(false, "minecraft", gamePath.text) }
                }
                XCTextField {
                    id: javaPath; width: parent.width; placeholderText: "Java 路径（可选）"; enabled: !MinecraftAssetImporter.importing
                }
                Row {
                    spacing: 8
                    ActionButton {
                        objectName: "initializationStartImport"
                        text: "开始导入"; primary: true
                        enabled: gamePath.text.trim().length > 0 && !MinecraftAssetImporter.importing
                        onClicked: root.importGame(gamePath.text, javaPath.text)
                    }
                    ActionButton { visible: MinecraftAssetImporter.importing; text: "取消导入"; onClicked: MinecraftAssetImporter.cancel() }
                    ActionButton { visible: !MinecraftAssetImporter.importing; text: "收起"; onClicked: root.showImport = false }
                }
                XCText { visible: MinecraftAssetImporter.status.length > 0; width: parent.width; onCenter: false; xcWrapMode: true; xcText: MinecraftAssetImporter.status; xcFontSize: 12; boldFont: false }
                Rectangle {
                    width: parent.width; height: 3; radius: 1.5; visible: MinecraftAssetImporter.importing
                    color: Colors.changeA(Colors.control, 0.5)
                    Rectangle { height: parent.height; radius: parent.radius; width: parent.width * Math.max(0.02, MinecraftAssetImporter.progress / 100); color: Colors.accentFill }
                }
                XCFolderDialog { id: gameDialog; title: "选择游戏目录或版本目录"; onAccepted: gamePath.text = selectedFolder.toString() }
                XCFileDialog { id: jarDialog; nameFilters: ["Minecraft 客户端 (*.jar)"]; onAccepted: gamePath.text = selectedFile.toString() }
                Component.onCompleted: {
                    var saved = root.readJson(root.itemsRoot + "/import-settings.json", {})
                    gamePath.text = saved.sourcePath || saved.clientJar || ""
                    javaPath.text = saved.javaPath || ""
                }
            }
            XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcText: "也可以稍后在设置中导入。"; xcFontSize: 12; boldFont: false; textColor: Colors.banned }
        }
    }
}
