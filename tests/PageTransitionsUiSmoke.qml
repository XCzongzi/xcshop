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
        {type: "Item", name: "a", page: Constants.pageOnItem},
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
    Component.onCompleted: {
        files.folder(project)
        files.write(project + "/xcshop.json", JSON.stringify({name: "切换测试", namespace: "transitions", version: "26.3", shops: []}))
        var itemA = Schema.item(); itemA.item = "stone"
        var itemB = Schema.item(); itemB.item = "gold_ingot"
        for (var type of ["UI", "Item", "Cost", "Display"]) files.folder(project + "/" + type)
        files.write(project + "/UI/a.xcseUI", "{}")
        files.write(project + "/Item/a.xcseItem", JSON.stringify(itemA))
        files.write(project + "/Item/b.xcseItem", JSON.stringify(itemB))
        files.write(project + "/Cost/a.xcseCost", "{}")
        files.write(project + "/Display/a.xcseDisplay", JSON.stringify(Schema.display()))
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
                        root.check(!motion.running && motion.contentOpacity === 1, "masked transition must not stack page fades")
                        root.stage++
                    }
                } else if (root.stage === 2) {
                    var route = root.routes[root.routeIndex]
                    var oldItem = loader.item
                    var oldType = Global.current_element
                    if (route.type === "Global") root.find(root.appWindow.contentItem, "workspaceTypeBar").typeBtnClicked("Global")
                    else SignalBus.elementOpenRequested(root.project + "/" + route.type + "/" + route.name + ".xcse" + route.type)
                    root.check(motion.running && loader.item === oldItem, "old page must stay alive during exit")
                    root.check(Global.current_element === oldType, "backing state must stay with outgoing page")
                    UiInput.settle(40)
                    root.check(motion.contentOpacity > 0 && motion.contentOpacity < 1 && motion.contentOffset < 0, "fade-out and movement must animate")
                    root.stage++
                } else if (root.stage === 3) {
                    var destination = root.routes[root.routeIndex]
                    root.check(!motion.running && motion.contentOpacity === 1 && motion.contentOffset === 0, "page transition must release input")
                    root.check(loader.sourceComponent === destination.page, "wrong page for " + destination.type)
                    root.check(Global.current_element === destination.type, "wrong backing state")
                    if (destination.type !== "Global") root.check(loader.item.dataLoaded, "element failed to load")
                    if (++root.routeIndex < root.routes.length) root.stage = 2
                    else {
                        root.check(JSON.parse(files.read(root.project + "/Item/a.xcseItem")).item.indexOf("stone") >= 0, "switching must preserve the previous file")
                        root.check(loader.item.eledata.item.indexOf("gold_ingot") >= 0, "same-page file switch must reload content")
                        root.find(root.appWindow.contentItem, "workspaceTypeBar").extraButton_clicked("settings")
                        root.stage++
                    }
                } else if (root.stage === 4) {
                    root.check(loader.sourceComponent === Constants.pageOnSettings && !motion.running, "settings entry")
                    var sectionMotion = root.find(loader.item, "settingsSectionTransition")
                    loader.item.currentSection = 1
                    root.check(sectionMotion.running && loader.item.displayedSection === 0, "settings must fade before replacing content")
                    UiInput.settle(35)
                    root.check(sectionMotion.contentOpacity > 0 && sectionMotion.contentOpacity < 1, "settings exit animation")
                    loader.item.currentSection = 2
                    loader.item.currentSection = 3
                    root.stage++
                } else if (root.stage === 5) {
                    var sections = root.find(loader.item, "settingsSectionTransition")
                    root.check(!sections.running && loader.item.displayedSection === 3, "rapid settings navigation must keep latest destination")
                    root.check(root.find(loader.item, "settingsSectionLoader").item.itemsRootPath.length > 0, "settings content mismatch")
                    Global.animationSpeed = 2
                    loader.item.currentSection = 0
                    UiInput.settle(220)
                    root.check(!sections.running && loader.item.displayedSection === 0, "transition must honor animation speed")
                    Global.animationSpeed = 1
                    loader.item.pageEvent("Settings.back", {})
                    root.stage++
                } else if (root.stage === 6) {
                    if (motion.running) { root.inStep = false; return }
                    root.check(!motion.running && loader.sourceComponent === Constants.pageOnItem, "settings return transition")
                    root.check(loader.item.eledata.item.indexOf("gold_ingot") >= 0, "settings return must preserve selected element")
                    console.log("PAGE_TRANSITIONS_UI_SMOKE_PASSED")
                    stop()
                    Qt.quit()
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
