pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop
import "../js/WorkspaceSchema.js" as Schema

Window {
    id: root
    visible: true
    width: 1; height: 1
    property var appWindow: null
    property int stage: 0
    property int routeIndex: 0
    property int ticks: 0
    property bool inStep: false
    readonly property string project: SMOKE_DIR + "/transition-project"
    readonly property var routes: [
        {type: "UI", name: "a", page: Constants.pageOnUI},
        {type: "Item", name: "a", page: Constants.pageOnItem},
        {type: "Cost", name: "a", page: Constants.pageOnCost},
        {type: "Display", name: "a", page: Constants.pageOnDisplay},
        {type: "Global", page: Constants.pageOnTotal},
        {type: "Item", name: "b", page: Constants.pageOnItem},
        {type: "UI", name: "b", page: Constants.pageOnUI, source: "relay"},
        {type: "Cost", name: "b", page: Constants.pageOnCost, source: "relay"},
        {type: "Display", name: "b", page: Constants.pageOnDisplay, source: "relay"},
        {type: "Global", page: Constants.pageOnTotal},
        {type: "Item", name: "a", page: Constants.pageOnItem, source: "problem"},
        {type: "Item", name: "b", page: Constants.pageOnItem}
    ]
    XCFile { id: files }
    Component { id: application; Main { width: 1000; height: 760 } }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) {
            var result = find(child, name)
            if (result) return result
        }
        return null
    }
    function findRelay(item) {
        if (item instanceof ElementRelayBar) return item
        for (var child of item.children) {
            var result = findRelay(child)
            if (result) return result
        }
        return null
    }
    function elementPath(route) {
        return project + "/" + route.type + (route.name === "b" ? "/nested/" : "/")
                + route.name + ".xcse" + route.type
    }
    function checkElementCreation() {
        Global.animationSpeed = 20
        Global.current_fileName = ["", "", "", "", ""]
        UiInput.settle(100)
        var loader = find(appWindow.contentItem, "mainPageLoader")
        var typeBar = find(appWindow.contentItem, "workspaceTypeBar")
        var tree = find(appWindow.contentItem, "explorerFileTree")
        var controls = find(appWindow.contentItem, "explorerFileControls")
        for (var type of ["UI", "Item", "Cost", "Display"]) {
            typeBar.typeBtnClicked(type)
            UiInput.settle(100)
            check(loader.sourceComponent === Constants.pageWithEmpty, "new workspace must start without a selected element")
            var previousPath = ""
            var previousContent = ""
            for (var folder of ["", "/nested"]) {
                tree.currentFolder = folder
                controls.requestCreate(false)
                UiInput.settle(80)
                var field = find(appWindow.contentItem, "popupTextInputField")
                check(field && field.activeFocus, "creation dialog must focus the element name")
                field.text = " 新元素 "
                UiInput.key(field, Qt.Key_Return)
                UiInput.settle(160)
                var createdPath = project + "/" + type + folder + "/新元素.xcse" + type
                check(files.exists(createdPath), "element creation failed for " + type)
                check(Global.normalizeElementPath(Global.get_filePath()) === createdPath,
                      "creation must select the new " + type + " element")
                check(loader.item.dataLoaded && loader.item.eledata.smokeTag === undefined
                      && loader.item.eledata.creationMarker === undefined, "creation must display fresh element data")
                check(tree.currentFolder === folder, "creation must keep the new element's directory visible")
                if (previousPath.length)
                    check(files.read(previousPath) === previousContent, "creation must preserve the previous element")
                loader.item.eledata.creationMarker = type + folder
                check(loader.item.updateDataOut(), "new element must be editable")
                check(JSON.parse(files.read(createdPath)).creationMarker === type + folder,
                      "editing must save to the created element")
                previousPath = createdPath
                previousContent = files.read(createdPath)
            }
        }
    }
    Component.onCompleted: {
        files.folder(project)
        files.write(project + "/xcshop.json", JSON.stringify({name: "切换测试", namespace: "transitions", version: "26.3", shops: []}))
        for (var type of ["UI", "Item", "Cost", "Display"]) {
            files.folder(project + "/" + type)
            files.folder(project + "/" + type + "/nested")
            for (var name of ["a", "b"]) {
                var data = type === "Item" ? Schema.item() : type === "Display" ? Schema.display() : ({})
                if (type === "Item") data.item = name === "a" ? "stone" : "gold_ingot"
                data.smokeTag = type + "/" + name
                files.write(elementPath({type: type, name: name}), JSON.stringify(data))
            }
        }
        appWindow = application.createObject(null)
        Global.animationSpeed = 1
    }
    Timer {
        interval: 450; repeat: true; running: true
        onTriggered: {
            if (root.inStep) return
            root.inStep = true
            try {
                root.check(++root.ticks < 60, "timed out at stage " + root.stage)
                var loader = root.find(root.appWindow.contentItem, "mainPageLoader")
                var motion = root.find(root.appWindow.contentItem, "mainPageTransition")
                var entrance = root.find(root.appWindow.contentItem, "workspaceEntrance")
                if (root.stage === 0) {
                    loader.item.openProject(root.project)
                    root.stage++
                } else if (root.stage === 1) {
                    if (!entrance.busy) {
                        root.check(loader.sourceComponent === Constants.pageOnTotal, "workspace entry")
                        root.check(!motion && loader.opacity === 1, "ordinary pages must not use the initialization transition")
                        root.stage++
                    }
                } else if (root.stage === 2) {
                    var route = root.routes[root.routeIndex]
                    if (route.source === "problem") {
                        loader.item.showBuildProblem({severity: "error", file: root.elementPath(route), reason: "导航回归测试"})
                        root.stage = 7
                        root.inStep = false
                        return
                    }
                    var oldItem = loader.item
                    if (route.type === "Global") root.find(root.appWindow.contentItem, "workspaceTypeBar").typeBtnClicked("Global")
                    else if (route.source === "relay") root.findRelay(root.appWindow.contentItem).useRecord({path: root.elementPath(route), type: route.type})
                    else SignalBus.elementOpenRequested(root.elementPath(route))
                    root.check(!motion && loader.opacity === 1, "workspace navigation must not fade or move the loader")
                    if (route.type !== "Global") {
                        root.check(loader.sourceComponent === route.page && loader.item !== oldItem,
                                   "workspace pages must skip the exit animation")
                        root.check(Global.current_element === route.type, "workspace selection must update immediately")
                        UiInput.settle(40)
                        root.check(loader.item.animateEntrance && loader.item.opacity > 0 && loader.item.opacity < 1,
                                   "workspace pages must keep their original entrance fade")
                    } else {
                        root.check(loader.item === oldItem, "overview navigation must keep the original exit fade")
                        UiInput.settle(40)
                        root.check(oldItem.opacity > 0 && oldItem.opacity < 1, "overview exit fade must animate")
                    }
                    root.stage++
                } else if (root.stage === 3) {
                    if (loader.item.opacity < 1) { root.inStep = false; return }
                    var destination = root.routes[root.routeIndex]
                    root.check(!motion && loader.opacity === 1, "ordinary page transition must not affect loader opacity")
                    root.check(loader.sourceComponent === destination.page, "wrong page for " + destination.type)
                    root.check(Global.current_element === destination.type, "wrong backing state")
                    if (destination.type !== "Global") {
                        root.check(loader.item.dataLoaded, "element failed to load")
                        root.check(loader.item.eledata.smokeTag === destination.type + "/" + destination.name,
                                   "wrong element content for " + destination.type + "/" + destination.name
                                   + ": " + loader.item.eledata.smokeTag)
                        root.check(Global.normalizeElementPath(Global.get_filePath()) === root.elementPath(destination), "wrong selected file")
                        root.check(root.find(root.appWindow.contentItem, "explorerDirectoryPath").xcText
                                   === "project:/" + destination.type + (destination.name === "b" ? "/nested" : ""),
                                   "explorer must show the target folder")
                        loader.item.eledata.navigationEdit = destination.type + "/" + destination.name
                        root.check(loader.item.updateDataOut(), "target element failed to save")
                        root.check(JSON.parse(files.read(root.elementPath(destination))).navigationEdit
                                   === destination.type + "/" + destination.name, "edits must save to the target element")
                    }
                    if (++root.routeIndex < root.routes.length) root.stage = 2
                    else {
                        root.check(JSON.parse(files.read(root.project + "/Item/a.xcseItem")).item.indexOf("stone") >= 0, "switching must preserve the previous file")
                        root.check(loader.item.eledata.item.indexOf("gold_ingot") >= 0, "same-page file switch must reload content")
                        root.find(root.appWindow.contentItem, "workspaceTypeBar").extraButton_clicked("settings")
                        root.stage++
                    }
                } else if (root.stage === 4) {
                    if (loader.item.opacity < 1) { root.inStep = false; return }
                    root.check(loader.sourceComponent === Constants.pageOnSettings && !motion, "settings entry")
                    root.check(!root.find(loader.item, "settingsSectionTransition"), "settings categories must not use initialization animations")
                    var previousSection = root.find(loader.item, "settingsSectionLoader").item
                    loader.item.currentSection = 1
                    root.check(root.find(loader.item, "settingsSectionLoader").item !== previousSection,
                               "settings categories must switch immediately")
                    loader.item.currentSection = 2
                    loader.item.currentSection = 3
                    root.stage++
                } else if (root.stage === 5) {
                    root.check(loader.item.currentSection === 3, "settings navigation must keep latest destination")
                    root.check(root.find(loader.item, "settingsSectionLoader").item.itemsRootPath.length > 0, "settings content mismatch")
                    Global.animationSpeed = 2
                    loader.item.currentSection = 0
                    UiInput.settle(220)
                    root.check(loader.item.currentSection === 0, "settings categories must remain immediate at another animation speed")
                    Global.animationSpeed = 1
                    loader.item.pageEvent("Settings.back", {})
                    root.stage++
                } else if (root.stage === 6) {
                    if (loader.item.opacity < 1) { root.inStep = false; return }
                    root.check(!motion && loader.sourceComponent === Constants.pageOnItem, "settings return transition")
                    root.check(loader.item.eledata.item.indexOf("gold_ingot") >= 0, "settings return must preserve selected element")
                    root.checkElementCreation()
                    console.log("PAGE_TRANSITIONS_UI_SMOKE_PASSED")
                    stop()
                    Qt.quit()
                } else if (root.stage === 7) {
                    var confirm = root.find(root.appWindow.contentItem, "noticeConfirmButton")
                    root.check(confirm && confirm.enabled, "build problem must offer element navigation")
                    confirm.clicked()
                    root.stage = 3
                }
            } catch (error) {
                console.error("PAGE_TRANSITIONS_UI_SMOKE_FAILED", error)
                stop()
                Qt.exit(1)
            }
            root.inStep = false
        }
    }
}
