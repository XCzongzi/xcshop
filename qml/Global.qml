pragma Singleton
import QtQuick
import xcshop

QtObject{

    //图形化界面信息
    property int window_width
    property int window_height

    //全局信息

    property Image mainWindow_background

    property real animationSpeed: 1.0
    property string backgroundMode: "color" // color / image
    property string backgroundImage: ""
    property real backgroundBlur: 0.45
    property string settingsPath: ""
    property var recentProjects: []
    property int elementRelayHeight: 160

    //项目信息
    property string project_location: ""
    property string version: ""
    property int syntaxVersion: 1



    property string current_element: "Total"
    property int current_enum: 0     //enum:element_number，用于以数字形式存储元素类型
    onCurrent_elementChanged:{
        function set_enum(){
            switch(current_element){
            case   "Total":return 0
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
    readonly property string current_file: current_fileLocation[current_enum] + "/" + current_fileName[current_enum] + ".xcse" + current_element    //动态计算当前整体文件路径
    function get_fileName(){
        return current_fileName[current_enum]
    }
    function get_fileLocation(containPrefix){    //获取文件路径，但不包含文件名
        return containPrefix ? "file:" + current_fileLocation[current_enum] : current_fileLocation[current_enum]
    }
    function get_filePath(){    //获取文件路径，包含文件名
        return current_fileLocation[current_enum] + "/" + current_fileName[current_enum] + ".xcse" + current_element

    }

//通过物品id获取纹理位置
    function getItemTexturePath(itemId){
        var value = itemId === undefined || itemId === null ? "" : String(itemId).trim()
        if (!value.length)
            return ""

        var separator = value.indexOf(":")
        var namespaceName = separator > 0 ? value.substring(0, separator) : "minecraft"
        var itemName = separator >= 0 ? value.substring(separator + 1) : value
        if (!itemName.length)
            return ""

        return APP_DIRPATH + "/assets/minecraft/items/assets/"
                + namespaceName + "/" + itemName + ".png"
    }


    function set_file(folder, name){    //若folder参数为"*"，则表示不改变文件路径，只改变文件名
        // 重新赋值数组以触发 QML 属性通知；直接改 var 数组下标不会可靠地刷新绑定。
        if(folder !== "*"){
            var locations = current_fileLocation.slice()
            locations[current_enum] = project_location + "/" + current_element + folder
            current_fileLocation = locations
        }
        var names = current_fileName.slice()
        names[current_enum] = name
        current_fileName = names
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

    //文件操作
    property XCFile xcfile: XCFile{}

    function loadSettings(){
        settingsPath = APP_DIRPATH + "/settings.json"
        var text = xcfile.read(settingsPath)
        try {
            var saved = text.length ? JSON.parse(text) : null
            if (!saved)
                return
            Colors.loadSettings(saved)
            if (saved.animationSpeed) animationSpeed = saved.animationSpeed
            if (saved.backgroundMode)
                // Older settings used a separate imageBlur mode. Blur is now
                // controlled solely by backgroundBlur, so preserve the image
                // while migrating the legacy mode.
                backgroundMode = saved.backgroundMode === "imageBlur" ? "image" : saved.backgroundMode
            if (saved.backgroundImage) backgroundImage = saved.backgroundImage
            if (saved.backgroundBlur !== undefined) backgroundBlur = saved.backgroundBlur
            if (Array.isArray(saved.recentProjects)) recentProjects = saved.recentProjects.slice(0, 6)
            if (saved.elementRelayHeight !== undefined)
                elementRelayHeight = Math.max(126, Math.min(420, Number(saved.elementRelayHeight)))
        } catch (error) {}
    }

    function saveSettings(){
        if (!settingsPath.length)
            return
        var settings = Colors.settingsData()
        settings.animationSpeed = animationSpeed
        settings.backgroundMode = backgroundMode
        settings.backgroundImage = backgroundImage
        settings.backgroundBlur = backgroundBlur
        settings.recentProjects = recentProjects
        settings.elementRelayHeight = elementRelayHeight
        xcfile.write(settingsPath, JSON.stringify(settings))
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
        recentProjects = records.slice(0, 6)
        saveSettings()
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
