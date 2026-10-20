pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    workspace: true

    property var projectData: ({})
    property bool manifestLoaded: false
    property var registeredShops: []
    readonly property var templateOptions: {
        var catalog = BuildKits.templates
        return BuildKits.options(projectData.dataVersion === undefined ? BuildKits.dataVersion : Number(projectData.dataVersion))
    }
    property var elementCounts: ({ "UI": 0, "Item": 0, "Cost": 0, "Display": 0 })
    property var preflightProblems: []
    readonly property bool hasBuildResult: Builder.projectPath.length > 0
                                          && Global.normalizeElementPath(Builder.projectPath).toLowerCase()
                                             === Global.normalizeElementPath(Global.project_location).toLowerCase()
    readonly property var buildProblems: preflightProblems.concat(hasBuildResult ? Builder.problems : [])
    readonly property bool builderAvailable: Builder.available
    readonly property bool building: Builder.running
    readonly property string buildState: building && !hasBuildResult ? "其他项目正在构建"
                                        : hasBuildResult ? Builder.state : builderAvailable ? "未构建" : "构建器不可用"
    readonly property string buildStage: hasBuildResult ? Builder.summary : ""
    readonly property real buildProgress: hasBuildResult && Builder.state === "构建成功" ? 1 : 0
    readonly property string buildConsole: hasBuildResult ? Builder.consoleText : ""
    readonly property string buildElapsed: hasBuildResult ? formatElapsed(Builder.elapsedMs) : "—"
    readonly property string buildOutputPath: hasBuildResult ? Builder.outputPath : ""

    readonly property int buildErrorCount: {
        var count = 0
        for (var i = 0; i < preflightProblems.length; ++i)
            if (String(preflightProblems[i].severity).toLowerCase() === "error")
                ++count
        return count
    }
    readonly property bool canBuild: manifestLoaded && builderAvailable && !building && buildErrorCount === 0

    // Preserve the four-card dashboard; on short windows keep controls from being squeezed out.
    content_height: dashboard.height + 36

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
        var data = clone(shop) || ({})
        data.element = shop && shop.element ? Global.projectRelativeElementPath(shop.element) : ""
        data.registrationName = String(shop && shop.registrationName || "")
        data.containerType = String(shop && shop.containerType || "")
        return data
    }

    function loadProject() {
        manifestLoaded = false
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
        if (loaded.shops !== undefined && !Array.isArray(loaded.shops)) {
            showNotice("项目配置读取失败", "xcshop.json 的 shops 必须是数组。当前配置未被修改，请修正后重新打开项目。")
            return
        }

        var rawShops = Array.isArray(loaded.shops) ? loaded.shops : []
        var shops = []
        for (var i = 0; i < rawShops.length; ++i)
            shops.push(normalizeShop(rawShops[i]))
        projectData = loaded
        manifestLoaded = true
        registeredShops = shops
        Global.version = loaded.version ? String(loaded.version) : ""
        refreshStatistics()
    }

    function saveManifest(nextProjectData, nextShops) {
        if (!manifestLoaded || building) return false
        var data = clone(nextProjectData)
        var shops = clone(nextShops)
        if (!data || !shops)
            return false
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
        if (changes.templateId !== undefined)
            delete next.template // Retire numeric identity only after an explicit template selection.
        saveManifest(next, registeredShops)
    }

    function editProject() {
        if (building) return
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
        if (building) return
        var next = registeredShops.slice()
        next.push(normalizeShop(shop))
        if (saveManifest(projectData, next)) {
            shopBar.feedbackMessage = "商店已注册"
            shopBar.feedbackIsError = false
            shopBar.clearNewShop()
        }
    }

    function updateShop(index, changes) {
        if (building) return
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
        if (building) return
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
        if (building) return
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
        if (!projectData.namespace || !/^[a-z0-9_.-]+$/.test(String(projectData.namespace))
                || projectData.namespace === "." || projectData.namespace === "..")
            result.push({ "severity": "error", "code": "E_NAMESPACE", "message": "项目命名空间格式不正确", "file": "xcshop.json" })
        if (!projectData.generatePath || !String(projectData.generatePath).trim().length)
            result.push({ "severity": "error", "code": "E_OUTPUT_PATH", "message": "未设置数据包生成位置", "file": "xcshop.json" })
        var manifest = Global.project_location + "/xcshop.json"
        var template = BuildKits.findTemplate(String(projectData.templateId || ""))
        if (!projectData.templateId)
            result.push({ "severity": "error", "message": "未设置模板 ID；旧数字模板需在项目设置中重新选择", "file": manifest, "property": "$.templateId", "solution": "打开项目设置，选择本地可用模板。" })
        else if (!template.valid || !BuildKits.identityValid)
            result.push({ "severity": "error", "message": "所选模板不可用或套件目录存在身份冲突", "file": manifest, "property": "$.templateId", "solution": "在设置 → 构建套件中检查模板与依赖，或重新选择模板。" })
        if (projectData.dataVersion !== BuildKits.dataVersion)
            result.push({ "severity": "error", "message": "当前编辑器不支持该项目数据版本", "file": manifest, "property": "$.dataVersion", "solution": "使用支持该项目数据版本的编辑器；不要直接改写版本号。" })
        if (template.valid && template.dataVersion !== projectData.dataVersion)
            result.push({ "severity": "error", "message": "模板与项目的数据版本不一致", "file": manifest, "property": "$.dataVersion", "solution": "请选择数据版本匹配的模板。" })
        if (template.valid && BuildKits.versionSupport(template.id, String(projectData.version || "")) < 0)
            result.push({ "severity": "error", "message": "模板不支持项目的目标版本", "file": manifest, "property": "$.version", "solution": "在项目设置中选择模板支持的版本。" })
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
        preflightProblems = collectProblems()
    }

    function formatElapsed(milliseconds) {
        var seconds = Math.max(0, Math.floor(milliseconds / 1000))
        var minutes = Math.floor(seconds / 60)
        seconds %= 60
        return minutes > 0 ? minutes + " 分 " + seconds + " 秒" : seconds + " 秒"
    }

    function beginBuild() {
        BuildKits.refresh()
        Builder.recheckExecutable()
        refreshStatistics()
        if (!canBuild)
            return
        Builder.start(Global.project_location, BuildKits.kitsPath)
    }

    Connections {
        target: SignalBus
        function onElementDataSaved() { root.refreshStatistics() }
        function onElementFilesMoved() { root.refreshStatistics() }
        function onElementFilesDeleted() { root.refreshStatistics() }
    }
    Connections {
        target: BuildKits
        function onCatalogChanged() { root.refreshStatistics() }
    }

    Component.onCompleted: { BuildKits.refresh(); Builder.recheckExecutable(); loadProject() }

    Item {
        id: dashboard
        x: 20
        y: 18 - root.height_output
        width: Math.max(0, parent.width - 40)
        height: Math.max(600, parent.height - 36)

        readonly property int gap: 16
        readonly property int topHeight: 196
        readonly property real projectWidth: (width - gap) * 0.62
        readonly property real shopWidth: (width - gap) * 0.44

        ProjectBar {
            id: projectBar
            width: dashboard.projectWidth
            contentHeight: dashboard.topHeight
            projectData: root.projectData
            projectLocation: Global.project_location
            templateOptions: root.templateOptions
            enabled: !root.building
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
            enabled: !root.building
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
            onCancelRequested: Builder.cancel()
            onProblemActivated: function(problem) {
                if (!problem || !problem.file)
                    return
                var parsed = Global.parseElementPath(problem.file)
                pageEvent("Popup.show", {
                    "component": Constants.popupNotice,
                    "properties": {
                        "title": String(problem.severity) === "warning" ? "构建警告" : "构建错误",
                        "content": String(problem.reason || problem.message || "")
                                   + "\n\n文件：" + problem.file
                                   + (problem.property ? "\n属性：" + problem.property : "")
                                   + (problem.solution ? "\n\n解决办法：" + problem.solution : "")
                                   + (parsed ? "\n\n确认后定位到此元素。" : "")
                    },
                    "callback": function(result) {
                        if (result === 1 && parsed && projectFile.exists(parsed.path))
                            SignalBus.elementOpenRequested(parsed.path)
                    }
                })
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
