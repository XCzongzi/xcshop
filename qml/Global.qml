pragma Singleton
import QtQuick
import xcshop

QtObject{

    //图形化界面信息
    property int window_width
    property int window_height

    //全局信息

    property Image mainWindow_background
    property Item mainWindow_backdrop: null
    property Item mainWindow_popupBackdrop: null
    property Item mainWindow_popupHost: null

    property real animationSpeed: 1.0
    property string backgroundMode: "color" // color / image
    property string backgroundImage: ""
    property real backgroundBlur: 0.45
    property string settingsPath: ""
    property bool initializationCompleted: false
    property string editorChineseFont: "Microsoft YaHei"
    property string editorLatinFont: "Consolas"
    property var customTextColors: []
    property var recentProjects: []
    readonly property int recentProjectLimit: 9
    property int elementRelayHeight: 160
    // 工作区内可拖动的面板尺寸统一保存在 settings.json。
    property int elementExplorerWidth: 150
    property int uiInspectorWidth: 400
    property var uiCanvasViews: ({})

    //项目信息
    property string project_location: ""
    property string version: ""
    readonly property int syntaxVersion: itemSyntaxVersion(version)

    function itemSyntaxVersion(gameVersion){
        var match = String(gameVersion).trim().match(/^(\d+)\.(\d+)(?:\.(\d+))?(?:$|-)/)
        // 未选择或无法识别版本时，保留默认的堆叠组件模式。
        if (!match)
            return 2

        // 按数字分段比较，兼容 26.1 起的年份版本号及省略补丁号的版本。
        var parts = [Number(match[1]), Number(match[2]), Number(match[3] || 0)]
        var componentsVersion = [1, 20, 5]
        for (var i = 0; i < componentsVersion.length; ++i) {
            if (parts[i] < componentsVersion[i])
                return 1 // NBT
            if (parts[i] > componentsVersion[i])
                return 2 // 堆叠组件
        }
        return 2
    }



    property string current_element: "Global"
    property int current_enum: 0     //enum:element_number，用于以数字形式存储元素类型
    onCurrent_elementChanged:{
        function set_enum(){
            switch(current_element){
            case   "Global":return 0
            case      "UI":return 1
            case    "Item":return 2
            case    "Cost":return 3
            case "Display":return 4
            default:return -1
            }
        }
        current_enum = set_enum()
    }

    property var current_fileLocation: ["","","","",""] //用列表来存储每个元素的当前文件信息，即可通过数字访问
    property var current_fileName: ["","","","",""]
    function get_fileName(){
        return current_fileName[current_enum]
    }
    function get_filePath(){    //获取文件路径，包含文件名
        return current_fileLocation[current_enum] + "/" + current_fileName[current_enum] + ".xcse" + current_element

    }

    property string minecraftPackPath: ""
    property var minecraftCustomIds: ({})
    property int minecraftIconRevision: 0
    property Connections minecraftImportConnection: Connections {
        target: MinecraftAssetImporter
        function onImportFinished(report) {
            if (report.ok) Global.reloadMinecraftResources()
        }
    }

    function reloadMinecraftResources(){
        var root = APP_DIRPATH + "/assets/minecraft/items"
        var pack = ""
        var custom = ({})
        var vanilla = ({})
        try {
            var active = JSON.parse(xcfile.read(root + "/active.json"))
            if (active.schemaVersion === 2
                    && /^packs\/[a-f0-9]{40}-r[0-9]+-[a-f0-9-]+$/.test(active.pack))
                pack = root + "/" + active.pack
        } catch (error) {}
        if (pack.length) {
            try {
                var catalog = JSON.parse(xcfile.read(pack + "/catalog.json"))
                for (var itemIndex = 0; itemIndex < catalog.items.length; ++itemIndex)
                    vanilla[catalog.items[itemIndex].name] = true
            } catch (error) { pack = "" }
        }
        try {
            var entries = JSON.parse(xcfile.read(root + "/custom-items.json"))
            for (var i = 0; i < entries.length; ++i)
                if (entries[i].itemId && !vanilla[entries[i].itemId]) custom[entries[i].itemId] = true
        } catch (error) {}
        minecraftPackPath = pack
        minecraftCustomIds = custom
        minecraftIconRevision += 1
    }

//通过物品id获取纹理位置
    function getItemTexturePath(itemId){
        var revision = minecraftIconRevision
        var value = itemId === undefined || itemId === null ? "" : String(itemId).trim()
        if (!value.length)
            return ""

        var separator = value.indexOf(":")
        var namespaceName = separator > 0 ? value.substring(0, separator) : "minecraft"
        var itemName = separator >= 0 ? value.substring(separator + 1) : value
        if (namespaceName === "." || namespaceName === ".."
                || !/^[a-z0-9_.-]+$/.test(namespaceName) || !/^[a-z0-9_./-]+$/.test(itemName)
                || itemName.split("/").some(function(part) { return !part.length || part === "." || part === ".." }))
            return ""

        var base = minecraftPackPath.length && !minecraftCustomIds[namespaceName + ":" + itemName]
                 ? minecraftPackPath : APP_DIRPATH + "/assets/minecraft/items"
        return base + "/assets/"
                + namespaceName + "/" + itemName + ".png"
    }


    function set_file(folder, name, elementType){    //若folder参数为"*"，则表示不改变文件路径，只改变文件名
        var type = elementType === undefined ? current_element : elementType
        var index = ["Global", "UI", "Item", "Cost", "Display"].indexOf(type)
        if (index < 0)
            return
        // 重新赋值数组以触发 QML 属性通知；直接改 var 数组下标不会可靠地刷新绑定。
        if(folder !== "*"){
            var locations = current_fileLocation.slice()
            locations[index] = project_location + "/" + type + folder
            current_fileLocation = locations
        }
        var names = current_fileName.slice()
        names[index] = name
        current_fileName = names
    }

    function fileEntryNameError(value){
        var name = String(value).trim()
        if (!name.length)
            return "名称不能为空。"
        if (name === "." || name === ".." || /[\\/:*?"<>|\x00-\x1f]/.test(name))
            return "名称不能包含 \\ / : * ? \" < > | 或控制字符。"
        if (/\.$/.test(name))
            return "名称不能以句点结尾。"
        if (/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(name))
            return "此名称为系统保留名称，请使用其它名称。"
        if (name.length > 240)
            return "名称过长，请控制在 240 个字符以内。"
        return ""
    }

    function normalizeElementPath(filePath){
        if (filePath === undefined || filePath === null)
            return ""
        return String(filePath).trim()
                               .replace(/^file:\/\/\/?/, "")
                               .replace(/^file:/, "")
                               .replace(/\\/g, "/")
                               .replace(/\/+$/, "")
    }

    // Element references are persisted relative to the project root.  Keep the
    // conversion here so selection widgets, element pages, and the relay bar
    // all use exactly the same convention.
    function isAbsoluteElementPath(path){
        return /^[A-Za-z]:\//.test(path) || /^\/+/.test(path)
    }

    function resolveElementPath(filePath){
        var path = normalizeElementPath(filePath)
        if (!path.length || isAbsoluteElementPath(path) || !project_location.length)
            return path

        var projectRoot = normalizeElementPath(project_location)
        return projectRoot + "/" + path.replace(/^\/+/, "")
    }

    function elementTypeFromPath(filePath){
        var path = normalizeElementPath(filePath)
        var match = path.match(/\.xcse(UI|Item|Cost|Display)$/i)
        if (!match)
            return ""
        switch (match[1].toLowerCase()) {
        case "ui": return "UI"
        case "item": return "Item"
        case "cost": return "Cost"
        case "display": return "Display"
        default: return ""
        }
    }

    function parseElementPath(filePath){
        var path = resolveElementPath(filePath)
        var type = elementTypeFromPath(path)
        if (!path.length || !type.length || !project_location.length)
            return null

        var projectRoot = normalizeElementPath(project_location)
        var typeRoot = projectRoot + "/" + type
        if (path.indexOf(typeRoot + "/") !== 0)
            return null

        var slash = path.lastIndexOf("/")
        var suffix = ".xcse" + type
        var fileName = path.substring(slash + 1)
        if (fileName.length <= suffix.length)
            return null

        return {
            "path": path,
            "type": type,
            "name": fileName.substring(0, fileName.length - suffix.length),
            "folder": path.substring(typeRoot.length, slash),
            "relativePath": path.substring(projectRoot.length + 1)
        }
    }

    function projectRelativeElementPath(filePath){
        var parsed = parseElementPath(filePath)
        return parsed ? parsed.relativePath : normalizeElementPath(filePath)
    }

    // 共用于单个连接与批量继承；写入前沿来源链检查失效引用和循环。
    function operationInheritanceError(targetPath, ownerPaths) {
        var owners = ownerPaths.map(function(path) { return resolveElementPath(path) })
        var visited = []
        var current = resolveElementPath(targetPath)
        while (current.length) {
            if (owners.indexOf(current) >= 0 || visited.indexOf(current) >= 0)
                return "操作组不能继承自身或形成循环，请选择其它 Item 元素。"
            visited.push(current)
            var element = parseElementPath(current)
            if (!element || element.type !== "Item" || !xcfile.exists(current))
                return "继承来源不是项目内存在的 Item 元素。"
            try {
                var data = JSON.parse(xcfile.read(current))
                if (!data || !Array.isArray(data.operations)
                        || (data.operationsFrom !== undefined && typeof data.operationsFrom !== "string"))
                    return "继承来源不是有效的操作组格式。"
                current = resolveElementPath(data.operationsFrom || "")
            } catch (error) {
                return "无法读取继承来源：" + error
            }
        }
        return ""
    }

    function outputFolderError(value) {
        if (value === undefined || value === null || value === "")
            return ""
        if (typeof value !== "string" || !value.trim().length
                || /[\\/:*?"<>|\x00-\x1f]/.test(value) || /[. ]$/.test(value)
                || value === "." || value === "..")
            return "文件夹名称不能包含路径或特殊字符，也不能以点或空格结尾"
        if (/^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])(\.|$)/i.test(value))
            return "此名称为系统保留名称，请换一个名称"
        return ""
    }

    function collectBuildProblems(projectData, registeredShops) {
        var result = []
        if (!projectData.name || !String(projectData.name).trim().length)
            result.push({ "severity": "error", "code": "E_PROJECT_NAME", "message": "项目名称为空", "file": "xcshop.json" })
        if (!projectData.namespace || !/^[a-z0-9_.-]+$/.test(String(projectData.namespace))
                || projectData.namespace === "." || projectData.namespace === "..")
            result.push({ "severity": "error", "code": "E_NAMESPACE", "message": "项目命名空间格式不正确", "file": "xcshop.json" })
        if (!projectData.generatePath || !String(projectData.generatePath).trim().length)
            result.push({ "severity": "error", "code": "E_OUTPUT_PATH", "message": "未设置数据包生成位置", "file": "xcshop.json" })
        var folderError = outputFolderError(projectData.outputFolder)
        if (folderError.length)
            result.push({ "severity": "error", "code": "E_OUTPUT_FOLDER", "message": folderError, "file": "xcshop.json", "property": "$.outputFolder" })
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
            var shop = registeredShops[i] || ({})
            var displayFile = shop.element || "xcshop.json"
            var name = String(shop.registrationName || "")
            if (!/^[a-z0-9_.-]+$/.test(name))
                result.push({ "severity": "error", "code": "E_SHOP_NAME", "message": "商店注册名格式不正确", "file": displayFile })
            else if (names.indexOf(name) >= 0)
                result.push({ "severity": "error", "code": "E_SHOP_NAME_DUPLICATE", "message": "商店注册名重复：" + name, "file": displayFile })
            names.push(name)

            var parsed = Global.parseElementPath(shop.element || "")
            if (!parsed || parsed.type !== "UI" || !xcfile.exists(parsed.path))
                result.push({ "severity": "error", "code": "E_REF_NOT_FOUND", "message": "商店连接的 UI 元素不存在", "file": displayFile })
            if (!Constants.shopContainerOptions.some(function(option) { return option.value === String(shop.containerType || "") }))
                result.push({ "severity": "error", "code": "E_CONTAINER_TYPE", "message": "商店容器类型不受支持", "file": displayFile })
        }
        return result
    }

    function requestBuild() {
        if (Builder.running || !project_location.length)
            return false
        BuildKits.refresh()
        Builder.recheckExecutable()
        var error = ""
        var data
        try {
            data = JSON.parse(xcfile.read(project_location + "/xcshop.json"))
        } catch (exception) {
            error = "无法解析项目根目录中的 xcshop.json。"
        }
        if (!error.length && (!data || typeof data !== "object" || Array.isArray(data)
                || (data.shops !== undefined && !Array.isArray(data.shops))))
            error = "xcshop.json 的根节点必须是对象，shops 必须是数组。"
        if (!error.length && !Builder.available)
            error = "构建器不可用，请在设置 → 构建器中检查可执行文件路径。"
        if (!error.length && BuildKits.acquiring)
            error = "正在获取构建套件，请完成或取消后再构建。"
        if (!error.length) {
            var problems = collectBuildProblems(data, data.shops || [])
            var errors = problems.filter(function(problem) { return problem.severity === "error" })
            if (errors.length)
                error = errors.map(function(problem) { return "• " + problem.message }).join("\n")
                        + "\n\n请在项目总览中检查并修正这些问题后重新构建。"
        }
        if (error.length) {
            SignalBus.sendToMain("Popup.show", {
                "component": Constants.popupNotice,
                "properties": { "title": "无法开始构建", "content": error }
            })
            return false
        }
        return Builder.start(project_location, BuildKits.kitsPath)
    }

    //文件操作
    property XCFile xcfile: XCFile{}
    property var savedSettings: ({})
    property Connections builderVersionConnection: Connections {
        target: Builder
        function onVersionInfoFetched() { Global.saveSettings() }
    }

    function loadSettings(){
        initializationCompleted = false
        customTextColors = []
        reloadMinecraftResources()
        settingsPath = APP_DIRPATH + "/settings.json"
        var text = xcfile.read(settingsPath)
        try {
            var saved = text.length ? JSON.parse(text) : null
            if (!saved)
                return
            if (typeof saved !== "object" || Array.isArray(saved))
                return
            savedSettings = saved
            customTextColors = normalizeTextColors(saved.customTextColors)
            initializationCompleted = saved.initializationCompleted === true
            editorChineseFont = typeof saved.editorChineseFont === "string" && saved.editorChineseFont.trim().length
                    ? saved.editorChineseFont.trim() : "Microsoft YaHei"
            editorLatinFont = typeof saved.editorLatinFont === "string" && saved.editorLatinFont.trim().length
                    ? saved.editorLatinFont.trim() : "Consolas"
            if (typeof saved.kitsPath === "string") BuildKits.kitsPath = saved.kitsPath
            if (typeof saved.builderPath === "string") Builder.executablePath = saved.builderPath
            if (typeof saved.builderVersionInfo === "string")
                Builder.restoreVersionInfo(saved.builderPath || "", saved.builderVersionInfo)
            if (typeof saved.builderStartupArguments === "string") Builder.startupArguments = saved.builderStartupArguments
            if (typeof saved.preferredTemplateId === "string") BuildKits.preferredTemplateId = saved.preferredTemplateId
            Colors.loadSettings(saved)
            if (saved.animationSpeed) animationSpeed = saved.animationSpeed
            if (saved.backgroundMode)
                backgroundMode = saved.backgroundMode === "image" ? "image" : "color"
            if (saved.backgroundImage) backgroundImage = saved.backgroundImage
            if (saved.backgroundBlur !== undefined) backgroundBlur = saved.backgroundBlur
            if (Array.isArray(saved.recentProjects)) recentProjects = saved.recentProjects.slice(0, recentProjectLimit)
            if (saved.elementRelayHeight !== undefined)
                elementRelayHeight = Math.max(126, Math.min(420, Number(saved.elementRelayHeight)))
            if (saved.elementExplorerWidth !== undefined)
                elementExplorerWidth = Math.max(150, Math.round(Number(saved.elementExplorerWidth)))
            if (saved.uiInspectorWidth !== undefined)
                uiInspectorWidth = Math.max(260, Math.round(Number(saved.uiInspectorWidth)))
            if (saved.uiCanvasViews && typeof saved.uiCanvasViews === "object"
                    && !Array.isArray(saved.uiCanvasViews))
                uiCanvasViews = saved.uiCanvasViews
        } catch (error) {}
    }

    function saveSettings(){
        if (!settingsPath.length)
            return
        var settings = Object.assign({}, savedSettings, Colors.settingsData())
        settings.initializationCompleted = initializationCompleted
        settings.animationSpeed = animationSpeed
        settings.editorChineseFont = editorChineseFont
        settings.editorLatinFont = editorLatinFont
        settings.customTextColors = customTextColors
        settings.backgroundMode = backgroundMode
        settings.backgroundImage = backgroundImage
        settings.backgroundBlur = backgroundBlur
        settings.recentProjects = recentProjects
        settings.elementRelayHeight = elementRelayHeight
        settings.elementExplorerWidth = elementExplorerWidth
        settings.uiInspectorWidth = uiInspectorWidth
        settings.uiCanvasViews = uiCanvasViews
        settings.kitsPath = BuildKits.kitsPath
        settings.builderPath = Builder.executablePath
        settings.builderVersionInfo = Builder.versionInfo
        settings.builderStartupArguments = Builder.startupArguments
        settings.preferredTemplateId = BuildKits.preferredTemplateId
        if (xcfile.writeAtomic(settingsPath, JSON.stringify(settings, null, 2))) {
            savedSettings = settings
            return true
        }
        console.warn("无法保存设置：" + settingsPath)
        return false
    }

    function normalizeTextColors(values) {
        var result = []
        if (!Array.isArray(values)) return result
        values.forEach(function(value) {
            var color = String(value).toLowerCase()
            if (/^#[0-9a-f]{6}$/.test(color) && result.indexOf(color) < 0)
                result.push(color)
        })
        return result
    }
    function addTextColor(value) {
        var next = normalizeTextColors(customTextColors.concat([value]))
        if (next.length === customTextColors.length) return
        customTextColors = next
        saveSettings()
    }
    function removeTextColor(value) {
        customTextColors = customTextColors.filter(function(color) { return color !== value })
        saveSettings()
    }
    function moveTextColor(value, offset) {
        var next = customTextColors.slice()
        var index = next.indexOf(value), target = index + offset
        if (index < 0 || target < 0 || target >= next.length) return
        next.splice(index, 1)
        next.splice(target, 0, value)
        customTextColors = next
        saveSettings()
    }
    function replaceTextColor(previous, value) {
        var next = customTextColors.slice()
        var index = next.indexOf(previous)
        if (index < 0 || next.indexOf(value) >= 0 || !/^#[0-9a-fA-F]{6}$/.test(value)) return
        next[index] = value.toLowerCase()
        customTextColors = normalizeTextColors(next)
        saveSettings()
    }

    function relayProjectKey(location){
        return normalizeElementPath(location || project_location)
    }

    function elementRelayPath(location){
        var key = relayProjectKey(location)
        return key.length ? key + "/.xcshop-relay.json" : ""
    }

    function cloneRelayState(state){
        try {
            return JSON.parse(JSON.stringify(state))
        } catch (error) {
            return null
        }
    }

    function elementRelayState(location){
        var relayPath = elementRelayPath(location)
        var stored = null
        try {
            var text = relayPath.length ? xcfile.read(relayPath) : ""
            stored = text.length ? JSON.parse(text) : null
        } catch (error) {
            stored = null
        }
        if (stored && typeof stored === "object") {
            var hydrated = cloneRelayState(stored) || { "recent": [], "favorites": [], "groups": [] }
            transformRelayRecordPaths(hydrated, resolveElementPath)
            return hydrated
        }

        return { "recent": [], "favorites": [], "groups": [] }
    }

    function saveElementRelayState(location, state){
        var relayPath = elementRelayPath(location)
        var serialized = cloneRelayState(state)
        if (!relayPath.length || !serialized)
            return
        transformRelayRecordPaths(serialized, projectRelativeElementPath)
        xcfile.write(relayPath, JSON.stringify(serialized))
    }

    function transformRelayRecordPaths(value, transformPath){
        if (!value || typeof value !== "object")
            return false
        var changed = false
        if (Array.isArray(value)) {
            for (var arrayIndex = 0; arrayIndex < value.length; ++arrayIndex)
                changed = transformRelayRecordPaths(value[arrayIndex], transformPath) || changed
            return changed
        }

        for (var key in value) {
            if (!Object.prototype.hasOwnProperty.call(value, key))
                continue
            if (key === "path" && typeof value[key] === "string") {
                var transformedPath = transformPath(value[key])
                if (transformedPath !== value[key]) {
                    value[key] = transformedPath
                    changed = true
                }
            }
            else
                changed = transformRelayRecordPaths(value[key], transformPath) || changed
        }
        return changed
    }

    function saveElementRelayHeight(value){
        elementRelayHeight = Math.max(126, Math.min(420, Math.round(value)))
        saveSettings()
    }

    function saveElementExplorerWidth(value){
        elementExplorerWidth = Math.max(150, Math.round(value))
        saveSettings()
    }

    function saveUiInspectorWidth(value){
        uiInspectorWidth = Math.max(260, Math.round(value))
        saveSettings()
    }

    function uiCanvasView(key){
        if (!key.length || !uiCanvasViews
                || !Object.prototype.hasOwnProperty.call(uiCanvasViews, key))
            return null
        var view = uiCanvasViews[key]
        return view && typeof view === "object" && !Array.isArray(view) ? view : null
    }

    function saveUiCanvasView(key, scale, offsetX, offsetY){
        if (!key.length || !isFinite(scale) || !isFinite(offsetX) || !isFinite(offsetY))
            return
        var views = ({})
        for (var viewKey in uiCanvasViews) {
            if (Object.prototype.hasOwnProperty.call(uiCanvasViews, viewKey))
                views[viewKey] = uiCanvasViews[viewKey]
        }
        views[key] = {
            "scale": scale,
            "offsetX": offsetX,
            "offsetY": offsetY
        }
        uiCanvasViews = views
        saveSettings()
    }
    function rememberProject(location, projectInfo){
        if (!location || !location.length)
            return

        var records = []
        for (var i = 0; i < recentProjects.length; ++i) {
            if (recentProjects[i].path !== location)
                records.push(recentProjects[i])
        }
        records.unshift({
            path: location,
            name: projectInfo && projectInfo.name ? projectInfo.name : location.split("/").pop(),
            namespace: projectInfo && projectInfo.namespace ? projectInfo.namespace : "",
            version: projectInfo && projectInfo.version ? projectInfo.version : ""
        })
        recentProjects = records.slice(0, recentProjectLimit)
        saveSettings()
    }
    function itemTextureSource(value) {
        var match = String(value || "").trim().match(/^([a-z0-9_.-]+(?::[a-z0-9_./-]+)?)/i)
        var path = getItemTexturePath(match ? match[1] : "")
        return path.length ? "file:///" + path.replace(/\\/g, "/") : ""
    }

    function removeRecentProject(location){
        var records = []
        for (var i = 0; i < recentProjects.length; ++i) {
            if (recentProjects[i].path !== location)
                records.push(recentProjects[i])
        }
        recentProjects = records
        saveSettings()
    }
}
