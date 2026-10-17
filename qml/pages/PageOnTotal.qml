pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    workspace: true

    property var projectData: ({})
    property var registeredShops: []
    property var templateOptions: []
    property var elementCounts: ({ "UI": 0, "Item": 0, "Cost": 0, "Display": 0 })
    property var buildProblems: []
    property bool builderAvailable: false
    property bool building: false
    property string buildState: builderAvailable ? "未构建" : "构建器未接入"
    property string buildStage: ""
    property real buildProgress: 0
    property string buildConsole: ""
    property double buildStartedAt: 0
    property string buildElapsed: "—"
    property string buildOutputPath: ""

    readonly property int buildErrorCount: {
        var count = 0
        for (var i = 0; i < buildProblems.length; ++i)
            if (String(buildProblems[i].severity).toLowerCase() === "error")
                ++count
        return count
    }
    readonly property bool canBuild: builderAvailable && !building && buildErrorCount === 0

    // Global 是固定仪表盘，内部列表各自滚动，不使用页面级纵向滚动。
    content_height: height

    XCFile { id: projectFile }

    function clone(value) {
        try {
            return JSON.parse(JSON.stringify(value))
        } catch (error) {
            return null
        }
    }

    function showNotice(title, message) {
        pageEvent("Popup.show", {
            "component": Constants.popupNotice,
            "properties": { "title": title, "content": message }
        })
    }

    function containerOptionExists(value) {
        for (var i = 0; i < Constants.shopContainerOptions.length; ++i)
            if (Constants.shopContainerOptions[i].value === value)
                return true
        return false
    }

    function normalizeShop(shop) {
        var defaultContainer = Constants.shopContainerOptions.length
                ? Constants.shopContainerOptions[0].value : ""
        return {
            "element": shop && shop.element ? Global.projectRelativeElementPath(shop.element)
                                             : (shop && shop.ui ? Global.projectRelativeElementPath(shop.ui) : ""),
            "registrationName": shop && shop.registrationName ? String(shop.registrationName)
                                                                : (shop && shop.name ? String(shop.name) : ""),
            "containerType": shop && containerOptionExists(String(shop.containerType || shop.containerId || ""))
                             ? String(shop.containerType || shop.containerId) : defaultContainer
        }
    }

    function loadTemplates() {
        var options = []
        try {
            var source = JSON.parse(projectFile.read("templates.json"))
            var items = source && Array.isArray(source.Intros) ? source.Intros : []
            for (var i = 0; i < items.length; ++i) {
                options.push({
                    "value": String(i),
                    "label": items[i].id ? String(items[i].id) : "模板 " + (i + 1),
                    "versions": Array.isArray(items[i].versions) ? items[i].versions : []
                })
            }
        } catch (error) {
        }

        var currentTemplate = projectData && projectData.template !== undefined
                ? String(projectData.template) : ""
        var found = false
        for (var j = 0; j < options.length; ++j)
            found = found || options[j].value === currentTemplate
        if (!found && currentTemplate.length) {
            options.push({
                "value": currentTemplate,
                "label": "模板 " + currentTemplate,
                "versions": projectData.version ? [String(projectData.version)] : []
            })
        }
        templateOptions = options
    }

    function loadProject() {
        var manifestPath = Global.project_location + "/xcshop.json"
        var loaded
        try {
            loaded = JSON.parse(projectFile.read(manifestPath))
        } catch (error) {
            showNotice("项目配置读取失败", "无法解析项目根目录中的 xcshop.json。")
            return
        }
        if (!loaded || typeof loaded !== "object" || Array.isArray(loaded)) {
            showNotice("项目配置读取失败", "xcshop.json 的根节点必须是对象。")
            return
        }

        var rawShops = Array.isArray(loaded.shops) ? loaded.shops : []
        var shops = []
        for (var i = 0; i < rawShops.length; ++i)
            shops.push(normalizeShop(rawShops[i]))
        projectData = loaded
        registeredShops = shops
        Global.version = loaded.version ? String(loaded.version) : ""
        buildOutputPath = loaded.generatePath ? String(loaded.generatePath) : ""
        loadTemplates()
        refreshStatistics()
    }

    function saveManifest(nextProjectData, nextShops) {
        var data = clone(nextProjectData)
        var shops = clone(nextShops)
        if (!data || !shops)
            return false
        if (data.dataVersion === undefined)
            data.dataVersion = 0
        data.shops = shops
        var saved = projectFile.writeAtomic(Global.project_location + "/xcshop.json",
                                            JSON.stringify(data, null, 2))
        if (!saved) {
            showNotice("保存失败", "无法写入项目配置文件，请检查文件权限。")
            return false
        }
        projectData = data
        registeredShops = shops
        Global.version = data.version ? String(data.version) : ""
        buildOutputPath = data.generatePath ? String(data.generatePath) : ""
        Global.rememberProject(Global.project_location, data)
        refreshStatistics()
        return true
    }

    function saveProjectChanges(changes) {
        var next = clone(projectData) || ({})
        for (var key in changes) {
            if (Object.prototype.hasOwnProperty.call(changes, key))
                next[key] = changes[key]
        }
        saveManifest(next, registeredShops)
    }

    function editProject() {
        pageEvent("Popup.show", {
            "component": Constants.popupProjectSettings,
            "properties": {
                "projectData": clone(projectData),
                "projectLocation": Global.project_location,
                "templateOptions": clone(templateOptions)
            },
            "callback": function(changes) {
                if (changes)
                    root.saveProjectChanges(changes)
            }
        })
    }

    function addShop(shop) {
        var next = registeredShops.slice()
        next.push(normalizeShop(shop))
        if (saveManifest(projectData, next)) {
            shopBar.feedbackMessage = "商店已注册"
            shopBar.feedbackIsError = false
            shopBar.clearNewShop()
        }
    }

    function updateShop(index, changes) {
        if (index < 0 || index >= registeredShops.length)
            return
        var next = clone(registeredShops)
        for (var key in changes) {
            if (Object.prototype.hasOwnProperty.call(changes, key))
                next[index][key] = changes[key]
        }
        saveManifest(projectData, next)
    }

    function editShop(index) {
        if (index < 0 || index >= registeredShops.length)
            return
        var existingNames = []
        for (var i = 0; i < registeredShops.length; ++i) {
            if (i !== index)
                existingNames.push(String(registeredShops[i].registrationName || ""))
        }
        pageEvent("Popup.show", {
            "component": Constants.popupShopSettings,
            "properties": {
                "shop": clone(registeredShops[index]),
                "containerOptions": clone(Constants.shopContainerOptions),
                "existingRegistrationNames": existingNames
            },
            "callback": function(changes) {
                if (changes)
                    root.updateShop(index, changes)
            }
        })
    }

    function requestDeleteShop(index) {
        if (index < 0 || index >= registeredShops.length)
            return
        var shop = registeredShops[index]
        pageEvent("Popup.show", {
            "component": Constants.popupNotice,
            "properties": {
                "title": "删除商店注册",
                "content": "确定删除“" + shop.registrationName + "”的注册吗？\nUI 元素文件不会被删除。",
                "doubleButton": true
            },
            "callback": function(result) {
                if (result !== 1)
                    return
                var next = registeredShops.slice()
                next.splice(index, 1)
                saveManifest(projectData, next)
            }
        })
    }

    function elementCount(typeName) {
        var suffix = ".xcse" + typeName.toLowerCase()
        var files = projectFile.filesInDirectory(Global.project_location + "/" + typeName)
        var count = 0
        for (var i = 0; i < files.length; ++i) {
            if (String(files[i]).toLowerCase().endsWith(suffix))
                ++count
        }
        return count
    }

    function validShop(shop) {
        if (!shop || !/^[a-z0-9_.-]+$/.test(String(shop.registrationName || "")))
            return false
        if (!containerOptionExists(String(shop.containerType || "")))
            return false
        var parsed = Global.parseElementPath(shop.element || "")
        return parsed && parsed.type === "UI" && projectFile.exists(parsed.path)
    }

    function collectProblems() {
        var result = []
        if (!projectData.name || !String(projectData.name).trim().length)
            result.push({ "severity": "error", "code": "E_PROJECT_NAME", "message": "项目名称为空", "file": "xcshop.json" })
        if (!projectData.namespace || !/^[a-z0-9_]+$/.test(String(projectData.namespace)))
            result.push({ "severity": "error", "code": "E_NAMESPACE", "message": "项目命名空间格式不正确", "file": "xcshop.json" })
        if (!projectData.generatePath || !String(projectData.generatePath).trim().length)
            result.push({ "severity": "error", "code": "E_OUTPUT_PATH", "message": "未设置数据包生成位置", "file": "xcshop.json" })
        if (projectData.template === undefined || projectData.template === null
                || String(projectData.template).length === 0)
            result.push({ "severity": "error", "code": "E_TEMPLATE", "message": "未设置构建模板", "file": "xcshop.json" })
        if (!projectData.version || !String(projectData.version).trim().length)
            result.push({ "severity": "error", "code": "E_TARGET_VERSION", "message": "未设置目标版本", "file": "xcshop.json" })
        if (registeredShops.length === 0)
            result.push({ "severity": "warning", "code": "W_NO_SHOPS", "message": "项目尚未注册商店", "file": "xcshop.json" })

        var names = []
        for (var i = 0; i < registeredShops.length; ++i) {
            var shop = registeredShops[i]
            var displayFile = shop.element || "xcshop.json"
            var name = String(shop.registrationName || "")
            if (!/^[a-z0-9_.-]+$/.test(name))
                result.push({ "severity": "error", "code": "E_SHOP_NAME", "message": "商店注册名格式不正确", "file": displayFile })
            else if (names.indexOf(name) >= 0)
                result.push({ "severity": "error", "code": "E_SHOP_NAME_DUPLICATE", "message": "商店注册名重复：" + name, "file": displayFile })
            names.push(name)

            var parsed = Global.parseElementPath(shop.element || "")
            if (!parsed || parsed.type !== "UI" || !projectFile.exists(parsed.path))
                result.push({ "severity": "error", "code": "E_REF_NOT_FOUND", "message": "商店连接的 UI 元素不存在", "file": displayFile })
            if (!containerOptionExists(String(shop.containerType || "")))
                result.push({ "severity": "error", "code": "E_CONTAINER_TYPE", "message": "商店容器类型不受支持", "file": displayFile })
        }
        return result
    }

    function refreshStatistics() {
        elementCounts = {
            "UI": elementCount("UI"),
            "Item": elementCount("Item"),
            "Cost": elementCount("Cost"),
            "Display": elementCount("Display")
        }

        var validCount = 0
        var validNames = []
        var referenced = []
        for (var i = 0; i < registeredShops.length; ++i) {
            var shopName = String(registeredShops[i].registrationName || "")
            if (validShop(registeredShops[i])
                    && validNames.indexOf(shopName) < 0) {
                ++validCount
                validNames.push(shopName)
                var uiPath = Global.normalizeElementPath(registeredShops[i].element)
                if (referenced.indexOf(uiPath) < 0)
                    referenced.push(uiPath)
            }
        }
        infoBar.validShopCount = validCount
        infoBar.referencedUiCount = referenced.length
        buildProblems = collectProblems()
    }

    function formatElapsed(milliseconds) {
        var seconds = Math.max(0, Math.floor(milliseconds / 1000))
        var minutes = Math.floor(seconds / 60)
        seconds %= 60
        return minutes > 0 ? minutes + " 分 " + seconds + " 秒" : seconds + " 秒"
    }

    function beginBuild() {
        refreshStatistics()
        if (!canBuild)
            return
        building = true
        buildState = "构建中"
        buildStage = "正在准备"
        buildProgress = 0
        buildConsole = ""
        buildStartedAt = Date.now()
        buildElapsed = "0 秒"
        pageEvent("Build.request", {
            "projectLocation": Global.project_location,
            "project": clone(projectData),
            "shops": clone(registeredShops)
        })
    }

    function appendBuildLog(level, message) {
        var prefix = level ? "[" + String(level).toUpperCase() + "] " : ""
        buildConsole += (buildConsole.length ? "\n" : "") + prefix + String(message || "")
    }

    function finishBuild(success, summary, outputPath) {
        building = false
        buildProgress = success ? 1 : buildProgress
        buildState = success ? "构建成功" : "构建失败"
        buildStage = summary || ""
        if (outputPath)
            buildOutputPath = String(outputPath)
        if (buildStartedAt > 0)
            buildElapsed = formatElapsed(Date.now() - buildStartedAt)
    }

    // 为构建器保留的统一回调入口。后端接入后可由 Main.qml 转发这些事件。
    function executeFromMain(type, parameters) {
        var data = parameters || ({})
        switch (type) {
        case "Build.available":
            builderAvailable = Boolean(data.available)
            if (!building)
                buildState = builderAvailable ? "未构建" : "构建器未接入"
            break
        case "Build.started":
            building = true
            buildState = "构建中"
            buildStage = data.stage || "正在准备"
            buildStartedAt = Date.now()
            buildElapsed = "0 秒"
            break
        case "Build.progress":
            buildProgress = Math.max(0, Math.min(1, Number(data.progress) || 0))
            buildStage = data.stage || buildStage
            break
        case "Build.log":
            appendBuildLog(data.level, data.message)
            break
        case "Build.problems":
            buildProblems = Array.isArray(data.problems) ? data.problems : []
            break
        case "Build.finished":
            finishBuild(Boolean(data.success), data.summary, data.outputPath)
            break
        case "Build.canceled":
            building = false
            buildState = "已取消"
            buildStage = ""
            break
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.building
        onTriggered: root.buildElapsed = root.formatElapsed(Date.now() - root.buildStartedAt)
    }

    Connections {
        target: SignalBus
        function onElementDataSaved() { root.refreshStatistics() }
        function onElementFilesMoved() { root.refreshStatistics() }
        function onElementFilesDeleted() { root.refreshStatistics() }
    }

    Component.onCompleted: loadProject()

    Item {
        id: dashboard
        x: 12
        y: 12
        width: Math.max(0, parent.width - 24)
        height: Math.max(0, parent.height - 24)

        readonly property int gap: 10
        readonly property int topHeight: Math.max(165, Math.min(220, height * 0.28))
        readonly property real projectWidth: Math.max(480, (width - gap) * 0.70)
        readonly property real shopWidth: (width - gap) * 0.48

        ProjectBar {
            id: projectBar
            width: dashboard.projectWidth
            contentHeight: dashboard.topHeight
            projectData: root.projectData
            projectLocation: Global.project_location
            templateOptions: root.templateOptions
            onEditRequested: root.editProject()
            onRevealRequested: function(path) {
                if (!projectFile.revealInFileManager(path))
                    root.showNotice("无法打开目录", "目录不存在或暂时无法访问。")
            }
        }

        ShopBar {
            id: shopBar
            y: dashboard.topHeight + dashboard.gap
            width: dashboard.shopWidth
            contentHeight: dashboard.height - y
            shops: root.registeredShops
            containerOptions: Constants.shopContainerOptions
            onAddRequested: function(shop) { root.addShop(shop) }
            onEditRequested: function(index) { root.editShop(index) }
            onDeleteRequested: function(index) { root.requestDeleteShop(index) }
            onLocateRequested: function(filePath) {
                var parsed = Global.parseElementPath(filePath)
                if (parsed && projectFile.exists(parsed.path))
                    SignalBus.elementOpenRequested(parsed.path)
                else
                    root.showNotice("无法定位元素", "连接的 UI 元素不存在。")
            }
        }

        BuildBar {
            id: buildBar
            x: shopBar.width + dashboard.gap
            y: shopBar.y
            width: dashboard.width - x
            contentHeight: dashboard.height - y
            builderAvailable: root.builderAvailable
            building: root.building
            canBuild: root.canBuild
            buildState: root.buildState
            buildStage: root.buildStage
            buildProgress: root.buildProgress
            elapsedText: root.buildElapsed
            outputPath: root.buildOutputPath
            consoleText: root.buildConsole
            problems: root.buildProblems
            onStartRequested: root.beginBuild()
            onCancelRequested: root.pageEvent("Build.cancel", {})
            onProblemActivated: function(problem) {
                if (!problem || !problem.file)
                    return
                var parsed = Global.parseElementPath(problem.file)
                if (parsed && projectFile.exists(parsed.path))
                    SignalBus.elementOpenRequested(parsed.path)
            }
        }

        InfoBar {
            id: infoBar
            x: projectBar.width + dashboard.gap
            width: dashboard.width - x
            contentHeight: dashboard.topHeight
            counts: root.elementCounts
            registeredShopCount: root.registeredShops.length
            onRefreshRequested: root.refreshStatistics()
        }
    }
}
