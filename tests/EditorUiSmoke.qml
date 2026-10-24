pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    width: 1280
    height: 900
    color: Colors.background
    property int step: 0
    property var page: null
    property string project: ""
    property string alpha: "7efaa610-f064-487d-a392-6cd8a711627e"
    XCFile { id: file }
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Colors.background
        // Keep the offscreen render loop active while asynchronous screenshots are read back.
        NumberAnimation on opacity { from: 0.999; to: 1; duration: 500; loops: Animation.Infinite }
    }
    Component { id: creating; PageOnCreating { fullScreen: false } }
    Component { id: total; PageOnTotal {} }
    Component { id: settings; PageOnSettings { fullScreen: false; currentSection: 1 } }
    Component { id: popupSettings; PopupProjectSettings {} }
    function check(value, message) { if (!value) throw new Error(message) }
    function show(component, properties) {
        if (page) page.destroy()
        page = component.createObject(frame, Object.assign({width: frame.width, height: frame.height}, properties || {}))
        check(page, "Failed to create QML page: " + component.errorString())
        page.width = Qt.binding(function() { return frame.width })
        page.height = Qt.binding(function() { return frame.height })
    }
    function screenshot(name) {
        frame.grabToImage(function(result) {
            result.saveToFile(APP_DIRPATH + "/ui-" + name + ".png")
        })
    }
    Component.onCompleted: {
        Global.animationSpeed = 20
        Global.settingsPath = SMOKE_DIR + "/settings.json"
        Global.savedSettings = {"futureSetting": "preserved"}
        BuildKits.preferredTemplateId = alpha
        timer.start()
    }
    Timer {
        id: timer
        interval: 350
        repeat: true
        onTriggered: {
            try {
                switch (root.step++) {
                case 0:
                    check(BuildKits.options(1).length >= 1, "bundled operation template not found")
                    show(creating)
                    break
                case 1:
                    page.projectNameValue = "ui-smoke"
                    page.namespaceValue = "ui-smoke.test"
                    page.storagePathValue = SMOKE_DIR + "/projects"
                    page.generatePathValue = SMOKE_DIR + "/generated"
                    check(page.currentTemplateId === alpha, "creation did not use shared preference")
                    check(page.canCreate, "creation validation mismatch")
                    screenshot("creating")
                    break
                case 2:
                    page.createProject()
                    check(page.projectCreationSucceeded, "createProject failed")
                    project = Global.project_location
                    var manifest = JSON.parse(file.read(project + "/xcshop.json"))
                    check(manifest.templateId === alpha && manifest.template === undefined, "legacy template identity written")
                    check(manifest.dataVersion === 1 && Array.isArray(manifest.shops), "manifest schema incorrect")
                    check(JSON.parse(file.read(Global.settingsPath)).futureSetting === "preserved", "settings dropped unknown fields")
                    check(file.writeAtomic(project + "/Item/stone.xcseItem", JSON.stringify({
                        "item": "stone 2", "display": {"mode": "original", "element": ""},
                        "operations": [{"title":"购买","showInDisplay":true,"cost":[],
                            "trigger":{"mode": {"kind": "take_item", "filter": {"kind": "none"}}, "execute": {"kind": "grant_item"}}}],
                        "itemSyntaxError": false
                    })), "item write failed")
                    check(file.writeAtomic(project + "/UI/shop.xcseUI", JSON.stringify({
                        "containerType": "generic_9x3", "customName": "Smoke", "openCommand": "",
                        "placeholderItem": {"enabled": false, "element": ""},
                        "slots": [{"index": 0, "items": [{"element": "Item/stone.xcseItem", "filter": {"scoreboard": "", "target": "", "score": ""}, "macros": []}]}],
                        "nestedGroups": []
                    })), "UI write failed")
                    show(total)
                    break
                case 3:
                    page.addShop({"registrationName": "smoke", "element": "UI/shop.xcseUI", "containerType": "barrel"})
                    check(page.registeredShops.length === 1, "shop registration disconnected")
                    check(page.canBuild, "dashboard failed preflight")
                    screenshot("dashboard")
                    break
                case 4:
                    page.beginBuild()
                    check(Builder.running, "build button disconnected")
                    show(settings) // Destroy dashboard while the build is running.
                    break
                case 5:
                    screenshot("kits")
                    check(page.sections[1].title === "构建套件" && page.sections[2].title === "构建器", "settings navigation incorrect")
                    break
                case 6:
                    page.currentSection = 2
                    break
                case 7:
                    screenshot("builder")
                    if (Builder.running) { --root.step; return }
                    check(Builder.result.buildSucceeded, "real builder failed: " + Builder.consoleText)
                    check(file.exists(Builder.outputPath + "/pack.mcmeta"), "datapack not generated")
                    break
                case 8:
                    show(total)
                    break
                case 9:
                    check(page.buildState === "构建成功", "build state lost after page change")
                    check(page.buildConsole.length > 0, "build console lost after page change")
                    screenshot("built")
                    break
                case 10:
                    root.width = 820
                    root.height = 480
                    break
                case 11:
                    page.setScrollOffset(160)
                    break
                case 12:
                    screenshot("dashboard-compact")
                    check(page.content_height >= page.height, "small viewport lost controls")
                    check(page.height_output > 0, "small viewport cannot scroll to lower controls")
                    break
                case 13:
                    root.width = 1280
                    root.height = 900
                    show(popupSettings, {projectData: page.projectData, projectLocation: project, templateOptions: BuildKits.options(1)})
                    // MultiEffect is unavailable on the software renderer; disable only this test dialog's shadow layer.
                    for (var i = 0; i < page.children.length; ++i)
                        if (page.children[i].layer.enabled) page.children[i].layer.enabled = false
                    page.open()
                    break
                case 14:
                    screenshot("project-settings")
                    break
                case 15:
                    page.submit()
                    check(page.result && page.result.templateId === alpha && page.result.template === undefined, "project settings corrupted template identity: " + page.validationMessage)
                    break
                case 16:
                    var brokenManifest = JSON.parse(file.read(project + "/xcshop.json"))
                    brokenManifest.shops = {"invalid": "must not be silently replaced"}
                    file.writeAtomic(project + "/xcshop.json", JSON.stringify(brokenManifest))
                    show(total)
                    break
                case 17:
                    check(!page.manifestLoaded && !page.canBuild, "invalid manifest still allowed building")
                    page.saveProjectChanges({"name": "must-not-save"})
                    check(JSON.parse(file.read(project + "/xcshop.json")).shops.invalid, "invalid manifest was overwritten")
                    console.log("UI_SMOKE_PASSED: creation, settings, real Alpha build, page lifecycle, project editing, invalid manifest protection")
                    Qt.exit(0)
                    break
                }
            } catch (error) {
                console.error("UI_SMOKE_FAILED step " + root.step + ": " + error)
                file.writeAtomic(APP_DIRPATH + "/ui-smoke-failure.txt", String(error) + "\n" + Builder.consoleText)
                Qt.exit(1)
            }
        }
    }
}
