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
    property bool inStep: false
    property var page: null
    property string project: ""
    property string alpha: "89755dae-f798-440d-b3a9-342ee8a9070f"
    property var validManifest: ({})
    property var popupRequest: null
    property string openedElement: ""
    property int detailsRequests: 0
    XCFile { id: file }
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Colors.background
        // Keep the offscreen render loop active while asynchronous screenshots are read back.
        NumberAnimation on opacity { from: 0.999; to: 1; duration: 500; loops: Animation.Infinite }
        FileControls {
            id: fileControls
            z: 100
            onBuildDetailsRequested: ++root.detailsRequests
        }
    }
    PopupLoader { id: problemPopup; anchors.fill: parent }
    Connections {
        target: SignalBus
        function onSendToMain(kind, parameters) {
            if (kind === "Popup.show") root.popupRequest = parameters
        }
        function onElementOpenRequested(path) { root.openedElement = path }
    }
    Component { id: creating; PageOnCreating { fullScreen: false } }
    Component { id: total; PageOnTotal {} }
    Component { id: settings; PageOnSettings { fullScreen: false; currentSection: 1 } }
    Component { id: popupSettings; PopupProjectSettings {} }
    Component {
        id: consoleTest
        Item {
            BuildBar {
                objectName: "consoleSample"
                x: 20; y: 20
                width: parent.width - 40
                contentHeight: parent.height - 40
                builderAvailable: true
                canBuild: true
                buildState: "构建成功"
            }
        }
    }
    function check(value, message) { if (!value) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var i = 0; i < item.children.length; ++i) {
            var result = find(item.children[i], name)
            if (result) return result
        }
        return null
    }
    function show(component, properties) {
        if (page) page.destroy()
        page = component.createObject(frame, Object.assign({width: frame.width, height: frame.height}, properties || {}))
        check(page, "Failed to create QML page: " + component.errorString())
        if (page.pageEvent !== undefined)
            page.pageEvent.connect(function(kind, parameters) {
                if (kind === "Popup.show") root.popupRequest = parameters
            })
        page.width = Qt.binding(function() { return frame.width })
        page.height = Qt.binding(function() { return frame.height })
    }
    function screenshot(name) {
        root.contentItem.grabToImage(function(result) {
            result.saveToFile(APP_DIRPATH + "/ui-" + name + ".png")
        })
    }
    function openProblem(path) {
        var list = find(page, "buildProblemsList")
        check(list, "Problem list missing")
        list.model = [{severity: "error", message: "测试问题", file: path,
                       property: "$.item", solution: "请修改元素配置"}]
        UiInput.settle(40)
        popupRequest = null
        UiInput.click(list, 30, 20)
        check(popupRequest && popupRequest.properties.title === "构建错误", "Problem row did not open details")
        problemPopup.open(popupRequest.component, popupRequest.properties, popupRequest.callback)
        UiInput.settle(80)
        check(problemPopup.item, "Problem popup was not created")
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
            if (root.inStep) return
            root.inStep = true
            try {
                switch (root.step++) {
                case 0:
                    check(BuildKits.options(0).length >= 1, "bundled operation template not found")
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
                    check(manifest.dataVersion === 0 && Array.isArray(manifest.shops), "manifest schema incorrect")
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
                    UiInput.click(find(fileControls, "quickBuildButton"))
                    check(Builder.running, "quick build button disconnected")
                    check(!find(fileControls, "quickBuildButton").enabled, "quick build allowed duplicate requests")
                    check(find(fileControls, "quickBuildStatus").text === "构建中…", "quick build has no running feedback")
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
                    check(find(fileControls, "quickBuildButton").enabled, "quick build did not recover after completion")
                    UiInput.click(find(fileControls, "quickBuildStatus"))
                    check(root.detailsRequests === 1, "build status cannot open details")
                    root.validManifest = JSON.parse(file.read(project + "/xcshop.json"))
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
                    show(popupSettings, {projectData: page.projectData, projectLocation: project, templateOptions: BuildKits.options(0)})
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
                    root.popupRequest = null
                    UiInput.click(find(fileControls, "quickBuildButton"))
                    check(!Builder.running && root.popupRequest.properties.title === "无法开始构建", "quick build bypassed invalid manifest validation")
                    show(consoleTest)
                    var logs = []
                    for (var line = 0; line < 3000; ++line)
                        logs.push("构建日志 " + line + " : data/example/function/shop/example.mcfunction")
                    find(page,"consoleSample").consoleText = logs.join("\n")
                    break
                case 18:
                    var viewport = find(page,"buildConsoleViewport")
                    var scroll = find(page,"buildConsoleScrollBar")
                    check(scroll.visible && scroll.size < 1,"long build console has no scrollbar")
                    check(find(page,"buildConsoleOutput").readOnly,"console is editable")
                    check(viewport.contentHeight > viewport.height,"console did not measure long output")
                    scroll.position = (1-scroll.size)/2
                    screenshot("console-long-dark")
                    break
                case 19:
                    var viewport = find(page,"buildConsoleViewport")
                    check(viewport.contentY > 0 && viewport.contentY < viewport.contentHeight-viewport.height,"scrollbar does not control console position")
                    viewport.setScrollOffset(viewport.contentHeight)
                    Colors.applyColorScheme("cloud")
                    screenshot("console-long-light")
                    break
                case 20:
                    var viewport = find(page,"buildConsoleViewport")
                    var scroll = find(page,"buildConsoleScrollBar")
                    check(Math.abs(viewport.contentY-viewport.contentHeight+viewport.height) < 2,"minimum scrollbar thumb prevents reaching final log line")
                    check(Math.abs(scroll.position+scroll.size-1) < 0.001,"console scroll position not synchronized")
                    Colors.applyColorScheme("midnight")
                    find(page,"consoleSample").consoleText += "\n末尾追加日志"
                    break
                case 21:
                    var scroll = find(page,"buildConsoleScrollBar")
                    scroll.position = 1-scroll.size
                    root.height = 320
                    break
                case 22:
                    var viewport = find(page,"buildConsoleViewport")
                    var scroll = find(page,"buildConsoleScrollBar")
                    check(viewport.height > 0 && scroll.height > 0,"compact console has invalid geometry")
                    scroll.position = 1-scroll.size
                    break
                case 23:
                    var viewport = find(page,"buildConsoleViewport")
                    check(Math.abs(viewport.contentY-viewport.contentHeight+viewport.height) < 2,"compact console cannot reach final log line")
                    find(page,"consoleSample").consoleText = "构建完成"
                    root.height = 900
                    break
                case 24:
                    var viewport = find(page,"buildConsoleViewport")
                    var scroll = find(page,"buildConsoleScrollBar")
                    check(!scroll.visible,"short console output leaves an unnecessary scrollbar: size="+scroll.size+" height="+viewport.height+" content="+viewport.contentHeight+" y="+viewport.contentY)
                    check(Math.abs(find(page,"buildConsoleViewport").contentY) < 1,"clearing long logs left the console scrolled")
                    find(page,"consoleSample").consoleText = ""
                    break
                case 25:
                    check(!find(page,"buildConsoleScrollBar").visible,"empty console has a scrollbar")
                    screenshot("console-empty")
                    for (var cycle = 0; cycle < 8; ++cycle) {
                        var sample = find(page, "consoleSample")
                        sample.building = true
                        sample.consoleText = "<当前构建 " + cycle + ">\n仅保留本次输出"
                        sample.building = false
                        var output = find(page, "buildConsoleOutput")
                        check(output.text === sample.consoleText, "repeated build " + cycle + " console mismatch: " + JSON.stringify(output.text) + " expected " + JSON.stringify(sample.consoleText))
                        sample.consoleText += "\n追加日志"
                        check(output.text === sample.consoleText, "console append was not synchronized")
                        check(!output.canUndo && !output.canRedo, "read-only console accumulated undo history")
                    }
                    file.writeAtomic(project + "/xcshop.json", JSON.stringify(root.validManifest))
                    show(total)
                    break
                case 26:
                    root.openedElement = ""
                    openProblem("Item/stone.xcseItem")
                    check(find(problemPopup.item, "noticeDismissButton").text === "确认", "problem dismiss label incorrect")
                    check(find(problemPopup.item, "noticeConfirmButton").text === "定位到此元素", "problem locate label incorrect")
                    screenshot("build-problem")
                    UiInput.click(find(problemPopup.item, "noticeDismissButton"))
                    break
                case 27:
                    check(!problemPopup.item && !root.openedElement.length, "confirm did not close the popup without navigating")
                    openProblem("Item/stone.xcseItem")
                    UiInput.key(problemPopup.item, Qt.Key_Return)
                    break
                case 28:
                    check(!problemPopup.item && !root.openedElement.length, "Enter did not close the popup without navigating")
                    openProblem("Item/stone.xcseItem")
                    UiInput.click(find(problemPopup.item, "noticeConfirmButton"))
                    break
                case 29:
                    check(!problemPopup.item && root.openedElement === Global.normalizeElementPath(project + "/Item/stone.xcseItem"), "locate did not open the problem element")
                    openProblem("xcshop.json")
                    check(!find(problemPopup.item, "noticeConfirmButton").enabled, "manifest problem allowed element navigation")
                    UiInput.key(problemPopup.item, Qt.Key_Return)
                    break
                case 30:
                    check(!problemPopup.item, "manifest problem cannot be dismissed")
                    openProblem("Item/missing.xcseItem")
                    check(!find(problemPopup.item, "noticeConfirmButton").enabled, "missing element allowed navigation")
                    UiInput.click(find(problemPopup.item, "noticeDismissButton"))
                    break
                case 31:
                    check(!problemPopup.item, "missing element problem cannot be dismissed")
                    Builder.executablePath = APP_DIRPATH + "/builder_protocol_fixture.exe"
                    root.validManifest.fixtureMode = "slow"
                    file.writeAtomic(project + "/xcshop.json", JSON.stringify(root.validManifest))
                    UiInput.click(find(fileControls, "quickBuildButton"))
                    check(Builder.running, "repeated quick build did not start")
                    show(total) // Opening build details must also work during an active build.
                    break
                case 32:
                    check(find(page, "buildConsoleOutput").text === Builder.consoleText, "new build console not synchronized")
                    check(Builder.consoleText.indexOf("[编辑器] 构建成功") < 0, "new build retained previous result log")
                    Builder.cancel()
                    break
                case 33:
                    if (Builder.running) { --root.step; return }
                    check(Builder.state === "已取消" && find(fileControls, "quickBuildButton").enabled, "cancelled quick build cannot be retried")
                    root.validManifest.fixtureMode = "success"
                    file.writeAtomic(project + "/xcshop.json", JSON.stringify(root.validManifest))
                    UiInput.click(find(fileControls, "quickBuildButton"))
                    check(Builder.running, "quick build retry failed")
                    break
                case 34:
                    if (Builder.running) { --root.step; return }
                    check(Builder.state === "构建成功", "quick build retry did not succeed")
                    check(find(fileControls, "quickBuildStatus").text === "构建成功", "quick build result feedback incorrect")
                    console.log("UI_SMOKE_PASSED: creation, settings, real Alpha build, quick build/retry/cancel, problem confirm/locate, page lifecycle, manifest validation, repeated build console and scrolling")
                    Qt.exit(0)
                    break
                }
            } catch (error) {
                timer.stop()
                console.error("UI_SMOKE_FAILED step " + root.step + ": " + error)
                file.writeAtomic(APP_DIRPATH + "/ui-smoke-failure.txt", String(error) + "\n" + Builder.consoleText)
                Qt.exit(1)
            } finally {
                root.inStep = false
            }
        }
    }
}
