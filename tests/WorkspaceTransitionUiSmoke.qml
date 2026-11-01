pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    width: 1000; height: 760
    property var appWindow: null
    property int stage: 0
    property int ticks: 0
    property string fixture: SMOKE_DIR + "/entrance-project"
    XCFile { id: files }
    Component { id: application; Main { width: 1000; height: 760 } }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) {
            var found = find(child, name)
            if (found) return found
        }
        return null
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    Component.onCompleted: {
        files.folder(fixture)
        files.write(fixture + "/xcshop.json", JSON.stringify({
            name: "星辰商店", namespace: "stars", shops: [], version: "1.21"
        }))
        appWindow = application.createObject(null)
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                root.ticks++
                var loader = root.find(root.appWindow.contentItem, "mainPageLoader")
                var entrance = root.find(root.appWindow.contentItem, "workspaceEntrance")
                if (root.stage === 1 || root.stage === 2) {
                    var actions = root.find(loader.item, "startActionsPanel")
                    var creation = root.find(loader.item, "startCreationPanel")
                    root.check(!(actions.visible && creation.visible), "start actions and creation form must never overlap")
                    root.check(actions.enabled && creation.enabled, "transition must preserve normal control appearance")
                    if (loader.item.creationProgress > 0 && loader.item.creationProgress < 1)
                        root.check(root.find(loader.item, "creationTransitionInputBlocker").visible, "fade must intercept input")
                }
                if (root.stage === 0 && root.ticks > 8) {
                    loader.item.openCreation()
                    root.stage = 1; root.ticks = 0
                } else if (root.stage === 1 && root.ticks === 1) {
                    root.check(loader.item.creationProgress > 0 && loader.item.creationProgress < 1, "creation must animate")
                } else if (root.stage === 1 && root.ticks > 6) {
                    root.check(root.find(loader.item, "startCreationPanel").opacity === 1, "creation fully revealed")
                    loader.item.closeCreation()
                    root.stage = 2; root.ticks = 0
                } else if (root.stage === 2 && root.ticks > 6) {
                    root.check(loader.item.creationProgress === 0, "back must restore start actions")
                    root.check(!root.find(loader.item, "startCreationPanel").visible, "creation hidden after back")
                    loader.item.openProject(root.fixture)
                    root.check(entrance.busy && !entrance.celebrating, "recent project entrance")
                    entrance.start(true, "duplicate")
                    root.check(!entrance.celebrating, "duplicate entrance must be ignored")
                    root.stage = 3; root.ticks = 0
                } else if (root.stage === 3 && root.ticks > 9) {
                    root.check(!entrance.busy && loader.sourceComponent === Constants.pageOnTotal, "recent workspace loaded")
                    root.check(entrance.contentOpacity === 1 && entrance.reveal === 1, "workspace fully restored")
                    // Exercise the event forwarded by the embedded creation form.
                    loader.sourceComponent = Constants.pageOnStart
                    loader.item.pageEvent("Creating.projectCreated", { name: "星辰商店" })
                    root.check(entrance.busy && entrance.celebrating, "created project entrance")
                    root.stage = 4; root.ticks = 0
                } else if (root.stage === 4 && root.ticks === 3) {
                    root.check(entrance.veil === 1 && entrance.reveal === 0, "mask stays opaque while the titlebar fill animates")
                    root.check(root.appWindow.titleBarColorFilling, "titlebar fill starts during the masked page switch")
                } else if (root.stage === 4 && root.ticks === 6) {
                    root.check(entrance.busy && entrance.reveal > 0 && entrance.veil < 1, "mask reveals after the titlebar fill finishes")
                    var foreground = root.find(root.appWindow.contentItem, "workspaceForeground")
                    root.check(foreground.opacity === entrance.contentOpacity && foreground.parent.opacity === 1, "only foreground fades; backdrop stays fully visible")
                    root.appWindow.contentItem.grabToImage(function(result) {
                        result.saveToFile(SMOKE_OUTPUT_DIR + "/workspace-entrance.png")
                    })
                } else if (root.stage === 4 && root.ticks > 9) {
                    root.check(!entrance.busy && !entrance.visible, "created project transition must release input promptly")
                    root.check(loader.sourceComponent === Constants.pageOnTotal && loader.item.manifestLoaded, "created workspace ready")
                    Global.current_fileName = ["", "previous-ui", "", "", ""]
                    UiInput.click(root.find(loader.item, "closeProjectButton"))
                    root.check(entrance.busy && entrance.closing, "close uses the shared transition")
                    root.check(entrance.projectName === "星辰商店", "close retains project title")
                    root.stage = 5; root.ticks = 0
                } else if (root.stage === 5 && root.ticks === 5) {
                    root.check(entrance.visible && entrance.closing, "closing transition remains visible after page switch")
                    root.appWindow.contentItem.grabToImage(function(result) {
                        result.saveToFile(SMOKE_OUTPUT_DIR + "/workspace-close.png")
                    })
                } else if (root.stage === 5 && root.ticks > 9) {
                    root.check(!entrance.busy, "closing transition completes")
                    root.check(loader.sourceComponent === Constants.pageOnStart, "close returns to start")
                    root.check(Global.project_location === "" && Global.version === "", "closed project state cleared")
                    root.check(Global.current_fileName.every(function(name) { return name === "" }), "element selections cleared")
                    root.check(files.exists(root.fixture + "/xcshop.json"), "closing preserves project files")
                    loader.item.openProject(root.fixture)
                    root.stage = 6; root.ticks = 0
                } else if (root.stage === 6 && root.ticks > 9) {
                    root.check(!entrance.busy && loader.sourceComponent === Constants.pageOnTotal && loader.item.manifestLoaded, "closed project can reopen")
                    UiInput.click(root.find(loader.item, "closeProjectButton"))
                    root.stage = 7; root.ticks = 0
                } else if (root.stage === 7 && root.ticks > 9) {
                    loader.item.pageEvent("Start.", { object: "settings" })
                    root.check(entrance.busy && loader.sourceComponent === Constants.pageOnStart, "settings waits for the shared mask before switching")
                    loader.pageSwitch(Constants.pageOnAbout)
                    root.check(entrance.destinationPage === Constants.pageOnSettings, "repeated navigation cannot replace the pending page")
                    root.stage = 8; root.ticks = 0
                } else if (root.stage === 8 && root.ticks === 3) {
                    root.check(entrance.veil === 1 && entrance.reveal === 0, "settings remains covered during titlebar animation")
                    root.check(!root.find(entrance, "aboutTransitionBrand").visible, "settings must not show the about brand")
                    root.check(loader.sourceComponent === Constants.pageOnSettings && root.appWindow.titleBarColorFilling, "settings keeps its filled titlebar")
                    root.check(Global.project_location === "", "settings navigation must not open a workspace")
                } else if (root.stage === 8 && root.ticks > 9) {
                    root.check(!entrance.busy && entrance.destinationPage === null, "settings transition releases input and clears its destination")
                    loader.item.pageEvent("Settings.back", {})
                    root.stage = 9; root.ticks = 0
                } else if (root.stage === 9 && root.ticks > 8) {
                    root.check(loader.sourceComponent === Constants.pageOnStart, "settings returns to start")
                    loader.item.pageEvent("Start.", { object: "about" })
                    root.check(entrance.busy && loader.sourceComponent === Constants.pageOnStart, "about uses the shared masked transition")
                    root.stage = 10; root.ticks = 0
                } else if (root.stage === 10 && root.ticks === 3) {
                    root.check(entrance.veil === 1 && entrance.reveal === 0, "about remains covered for the same interval")
                    root.check(loader.sourceComponent === Constants.pageOnAbout && !root.appWindow.titleBarColorFilling, "about keeps its transparent titlebar")
                    root.check(loader.item.width === root.appWindow.surfaceWidth && loader.item.height === root.appWindow.surfaceHeight, "about keeps its full-window layout")
                } else if (root.stage === 10 && root.ticks === 6) {
                    var brand = root.find(entrance, "aboutTransitionBrand")
                    root.check(brand.visible && brand.opacity === 1 && brand.scale === 1, "about brand finishes its fade, rise and scale before the page reveal")
                    root.check(root.find(brand, "aboutTransitionLogo").status === Image.Ready, "about transition logo loads")
                    root.check(root.find(brand, "aboutTransitionName").text === "XCzongzi", "about transition shows the requested name")
                    root.appWindow.contentItem.grabToImage(function(result) {
                        result.saveToFile(SMOKE_OUTPUT_DIR + "/about-brand-transition.png")
                    })
                } else if (root.stage === 10 && root.ticks === 10) {
                    root.check(entrance.brandReveal === 0 && entrance.reveal > 0, "about brand fades out before the page is revealed")
                } else if (root.stage === 10 && root.ticks > 15) {
                    root.check(!entrance.busy && entrance.contentOpacity === 1 && entrance.reveal === 1, "about transition fully restores foreground and input")
                    loader.item.pageEvent("About.back", {})
                    root.stage = 11; root.ticks = 0
                } else if (root.stage === 11 && root.ticks > 8) {
                    root.check(loader.sourceComponent === Constants.pageOnStart && Global.project_location === "", "about returns to start without changing project state")
                    console.log("WORKSPACE_TRANSITION_UI_SMOKE_PASSED")
                    Qt.quit()
                }
                if (root.ticks > 60) throw new Error("transition timed out")
            } catch (error) {
                console.error("WORKSPACE_TRANSITION_UI_SMOKE_FAILED: " + error)
                Qt.exit(1)
            }
        }
    }
}
