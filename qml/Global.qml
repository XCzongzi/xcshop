pragma Singleton
import QtQuick
import xcshop

QtObject{

    //图形化界面信息
    property int window_width
    property int window_height

    //全局信息

    property Image mainWindow_background

    // 运行时界面偏好；后续可集中接入配置文件持久化。
    property color themeColor: "#00aaFF"
    property real animationSpeed: 1.0
    property string backgroundMode: "color" // color / image / imageBlur
    property color backgroundColor: "#1b1d27"
    property string colorScheme: "midnight"
    property string backgroundImage: ""
    property real backgroundBlur: 0.45
    property string settingsPath: ""
    property var recentProjects: []
    property int elementRelayHeight: 160

    function applyColorScheme(scheme) {
        var palettes = {
            "midnight": { background: "#1b1d27", backgroundOverlay: "#aa1b1d27", foreground: "#aa41434f", fired: "#aa92949c", pressed: "#aa6b6c74", text: "#ffffff", banned: "#bbbbbb", highlight: "#4bffffff" },
            "cloud": { background: "#edf2f7", backgroundOverlay: "#e8edf2f7", foreground: "#e0dce5ee", fired: "#d1b6c3d1", pressed: "#d1aebaca", text: "#172033", banned: "#637087", highlight: "#60ffffff" },
            "slate": { background: "#202b38", backgroundOverlay: "#aa202b38", foreground: "#aa45586c", fired: "#aa7b93aa", pressed: "#aa526b82", text: "#f3f8ff", banned: "#b6c2cf", highlight: "#42ffffff" },
            "glacier": { background: "#eaf5fa", backgroundOverlay: "#e8eaf5fa", foreground: "#e0d5e8f0", fired: "#d1a6c6d5", pressed: "#d187adbf", text: "#123047", banned: "#5d7585", highlight: "#60ffffff" },
            "violet": { background: "#2b2238", backgroundOverlay: "#aa2b2238", foreground: "#aa5b476d", fired: "#aa9b7cb2", pressed: "#aa72588a", text: "#fff8ff", banned: "#cbbfd2", highlight: "#45ffffff" },
            "lavender": { background: "#f4eff9", backgroundOverlay: "#e8f4eff9", foreground: "#e0e6dcef", fired: "#d1c5afd5", pressed: "#d1b9a2c9", text: "#2c2039", banned: "#75667e", highlight: "#60ffffff" },
            "forest": { background: "#162d2d", backgroundOverlay: "#aa162d2d", foreground: "#aa345b58", fired: "#aa6f9b91", pressed: "#aa46756f", text: "#f3fffb", banned: "#b8cac4", highlight: "#42ffffff" },
            "mint": { background: "#e9f5ef", backgroundOverlay: "#e8e9f5ef", foreground: "#e0d4e9de", fired: "#d1a8cdb9", pressed: "#d188b59c", text: "#17352d", banned: "#5e7a6e", highlight: "#60ffffff" },
            "amber": { background: "#33251d", backgroundOverlay: "#aa33251d", foreground: "#aa654c3c", fired: "#aaa88769", pressed: "#aa815b43", text: "#fff9f3", banned: "#d3c2b4", highlight: "#45ffffff" },
            "parchment": { background: "#fbf3e5", backgroundOverlay: "#e8fbf3e5", foreground: "#e0ead8bd", fired: "#d1d5b888", pressed: "#d1c7a66f", text: "#3d2d1f", banned: "#81705c", highlight: "#60ffffff" },
            "rose": { background: "#38232e", backgroundOverlay: "#aa38232e", foreground: "#aa704658", fired: "#aaa57b8b", pressed: "#aa89596e", text: "#fff7f9", banned: "#d5bec6", highlight: "#45ffffff" },
            "blush": { background: "#f9edf1", backgroundOverlay: "#e8f9edf1", foreground: "#e0eed8e1", fired: "#d1d3a8b9", pressed: "#d1c5899f", text: "#3b2430", banned: "#816371", highlight: "#60ffffff" }
        }
        var palette = palettes[scheme] || palettes.midnight
        colorScheme = palettes[scheme] ? scheme : "midnight"
        backgroundColor = palette.background
        Colors.background_n = palette.background
        Colors.background = palette.backgroundOverlay
        Colors.foreground = palette.foreground
        Colors.fired = palette.fired
        Colors.pressed = palette.pressed
        Colors.text = palette.text
        Colors.banned = palette.banned
        Colors.glass_highlight = palette.highlight
    }

    
    //项目信息
    property string project_location: ""
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


    function set_file(folder, name){    //若folder参数为"*"，则表示不改变文件路径，只改变文件名
        if(folder !== "*")current_fileLocation[current_enum] = project_location + "/" + current_element + folder
        current_fileName[current_enum] = name
    }

    function normalizeElementPath(filePath){
        if (filePath === undefined || filePath === null)
            return ""
        return String(filePath).trim()
                               .replace(/^file:\/\/\/?/, "")
                               .replace(/\\/g, "/")
                               .replace(/\/+$/, "")
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
        var path = normalizeElementPath(filePath)
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


    //文件操作
    property int current_file_index:0
    property XCFile xcfile: XCFile{}

    function loadSettings(){
        settingsPath = APP_DIRPATH + "/settings.json"
        var text = xcfile.read(settingsPath)
        try {
            var saved = text.length ? JSON.parse(text) : null
            if (!saved)
                return
            if (saved.themeColor) themeColor = saved.themeColor
            if (saved.animationSpeed) animationSpeed = saved.animationSpeed
            if (saved.backgroundMode) backgroundMode = saved.backgroundMode
            if (saved.colorScheme) applyColorScheme(saved.colorScheme)
            if (saved.backgroundColor) backgroundColor = saved.backgroundColor
            if (saved.backgroundImage) backgroundImage = saved.backgroundImage
            if (saved.backgroundBlur !== undefined) backgroundBlur = saved.backgroundBlur
            if (Array.isArray(saved.recentProjects)) recentProjects = saved.recentProjects.slice(0, 6)
            if (saved.elementRelayHeight !== undefined)
                elementRelayHeight = Math.max(126, Math.min(420, Number(saved.elementRelayHeight)))
        } catch (error) {}
        Colors.border = themeColor
    }

    function saveSettings(){
        if (!settingsPath.length)
            return
        xcfile.write(settingsPath, JSON.stringify({
            themeColor: themeColor,
            animationSpeed: animationSpeed,
            backgroundMode: backgroundMode,
            backgroundColor: backgroundColor,
            colorScheme: colorScheme,
            backgroundImage: backgroundImage,
            backgroundBlur: backgroundBlur,
            recentProjects: recentProjects,
            elementRelayHeight: elementRelayHeight
        }))
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
        if (stored && typeof stored === "object")
            return cloneRelayState(stored) || { "recent": [], "favorites": [], "groups": [] }

        return { "recent": [], "favorites": [], "groups": [] }
    }

    function saveElementRelayState(location, state){
        var relayPath = elementRelayPath(location)
        var serialized = cloneRelayState(state)
        if (!relayPath.length || !serialized)
            return
        xcfile.write(relayPath, JSON.stringify(serialized))
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
    //普通
    function file_modify_name(text){
        Console.output("modify name")
        Console.output(Qt.resolvedUrl(get_filePath()))
        Console.output(xcfile.rename(get_filePath(), get_fileLocation(false)+ "/" + text + ".xcse" + current_element))
        current_fileName[current_enum] = text
    }
    function file_delete(){
        xcfile.remove_file(get_filePath())
        //SignalBus.elementIndexReset(current_file_index)
    }
    function file_clone(){
        Console.output("clone")
        Console.output(xcfile.clone(get_filePath()))
        //SignalBus.elementIndexRefresh(get_fileLocation(true),get_fileName())
    }
    function file_save_content(key, value){
        
    }
    

}
