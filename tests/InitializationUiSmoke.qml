pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    width: 1; height: 1
    property var appWindow: null
    property int stage: 0
    property int ticks: 0
    readonly property string itemsRoot: APP_DIRPATH + "/assets/minecraft/items"
    readonly property string pack: "packs/" + "a".repeat(40) + "-r1-abc"
    readonly property bool hasUpdate: INITIALIZATION_TEST_MODE === "update"
    XCFile { id: files }
    Component { id: application; Main { width: 1000; height: 760 } }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) {
            var found = find(child, name)
            if (found) return found
        }
        return null
    }
    function click(name) {
        var target = find(appWindow.contentItem, name)
        check(target && target.visible && target.enabled, "unavailable action " + name)
        UiInput.click(target)
    }
    function capture(name) {
        // Capture the page directly; software rendering cannot draw the window's GPU mask.
        find(appWindow.contentItem, "mainPageLoader").item.grabToImage(function(result) {
            result.saveToFile(SMOKE_OUTPUT_DIR + "/initialization-" + INITIALIZATION_TEST_MODE + "-" + name + ".png")
        })
    }
    function reopen() {
        if (appWindow) {
            find(appWindow.contentItem, "mainPageLoader").sourceComponent = null
            appWindow.close()
            appWindow.destroy()
        }
        appWindow = application.createObject(null)
    }
    Component.onCompleted: {
        files.folder(itemsRoot)
        files.write(itemsRoot + "/items.json", JSON.stringify([{name: "minecraft:stone"}, {name: "minecraft:diamond"}]))
        reopen()
        var page = find(appWindow.contentItem, "mainPageLoader").item
        check(page && page.step === "welcome" && !page.checkComplete, "first launch must wait for checking")
        page.begin()
        check(page.step === "welcome", "checking must block start")
    }
    Timer {
        interval: 400; running: true; repeat: true
        onTriggered: {
            try {
                if (++root.ticks > 65) throw new Error("timed out at stage " + root.stage)
                var loader = root.find(root.appWindow.contentItem, "mainPageLoader")
                var page = loader.item
                root.check(!root.find(root.appWindow.contentItem, "updateNotice"), "onboarding must own update notice")
                if (root.stage === 0) {
                    if (!page.checkComplete) return
                    root.check(root.appWindow.initializing && loader.sourceComponent === Constants.pageOnInitialize, "first launch route")
                    root.check(loader.x === 0 && page.x === 0 && page.width === root.appWindow.surfaceWidth, "full window layout")
                    root.capture("welcome")
                } else if (root.stage === 1) {
                    root.click("initializationWelcomeAction")
                    root.check(page.step === (root.hasUpdate ? "update" : "theme"), "update branch")
                } else if (root.stage === 2) {
                    if (root.hasUpdate) {
                        root.capture("update")
                        root.click("initializationViewUpdate")
                        root.check(UpdateFixture.openedCount() === 1, "update browser action")
                        root.click("initializationNext")
                    }
                    root.check(page.step === "theme", "theme must follow welcome/update")
                    root.capture("theme-dark")
                } else if (root.stage === 3) {
                    root.click("initializationTheme_glacier")
                    root.check(Colors.colorScheme === "glacier", "live theme preview")
                    root.appWindow.width = root.appWindow.minimumWidth
                    root.appWindow.height = root.appWindow.minimumHeight
                } else if (root.stage === 4) {
                    root.capture("theme-light-small")
                    root.click("initializationNext")
                    root.check(page.step === "templates", "template step")
                    root.check(!JSON.parse(files.read(Global.settingsPath)).initializationCompleted, "partial setup cannot mark complete")
                } else if (root.stage === 5) {
                    root.capture("templates")
                    root.reopen()
                } else if (root.stage === 6) {
                    if (!page.checkComplete) return
                    root.check(page.step === "welcome" && root.appWindow.initializing, "interrupted setup must reopen")
                    root.click("initializationWelcomeAction")
                    if (root.hasUpdate) root.click("initializationNext")
                } else if (root.stage === 7) {
                    root.check(page.step === "theme" && Colors.colorScheme === "glacier", "restore chosen theme")
                    root.click("initializationNext")
                } else if (root.stage === 8) {
                    root.check(BuildKits.templates.length > 0 && BuildKits.templates[0].versions.length > 0, "bundled templates and coverage")
                    root.check(root.find(page, "initializationDownloadTemplates").enabled, "online acquisition entry")
                    root.click("initializationNext")
                } else if (root.stage === 9) {
                    root.check(page.step === "items" && page.mappedItems.length === 2 && page.missingIcons === 2, "legacy mappings")
                    files.folder(root.itemsRoot + "/" + root.pack)
                    files.write(root.itemsRoot + "/active.json", JSON.stringify({schemaVersion: 2, pack: root.pack}))
                    files.write(root.itemsRoot + "/" + root.pack + "/catalog.json", JSON.stringify({schemaVersion: 2, gameVersion: "26.3", items: [{name: "minecraft:stone", iconStatus: "missing"}]}))
                    page.loadMappings()
                    root.check(page.mappingVersion === "26.3" && page.mappedItems.length === 1, "current pack mappings")
                } else if (root.stage === 10) {
                    root.capture("items")
                    root.click("initializationImportGame")
                    root.find(page, "initializationGamePath").text = APP_DIRPATH + "/missing-game"
                } else if (root.stage === 11) {
                    root.click("initializationStartImport")
                    root.check(MinecraftAssetImporter.importing, "import action must use backend")
                    root.check(!root.find(page, "initializationNext").enabled && !root.find(page, "initializationBack").enabled, "import must lock navigation")
                } else if (root.stage === 12) {
                    if (MinecraftAssetImporter.importing) return
                    root.check(page.errorText.length > 0 && !Global.initializationCompleted, "import failure must remain recoverable")
                    root.capture("import-error")
                    files.remove_file(root.itemsRoot + "/active.json")
                    files.remove_file(root.itemsRoot + "/items.json")
                    page.loadMappings()
                    root.check(page.mappedItems.length === 0, "empty distribution")
                    root.click("initializationBack")
                    root.click("initializationNext")
                } else if (root.stage === 13) {
                    Global.settingsPath = APP_DIRPATH // Atomic write to a directory must fail.
                    root.click("initializationNext")
                    root.check(page.step === "items" && page.errorText.length > 0 && !Global.initializationCompleted, "save failure must preserve setup")
                    Global.settingsPath = APP_DIRPATH + "/settings.json"
                    root.click("initializationNext")
                } else if (root.stage === 14) {
                    if (loader.sourceComponent !== Constants.pageOnStart) return
                    root.check(!root.appWindow.initializing && Global.initializationCompleted, "finish route")
                    root.check(JSON.parse(files.read(Global.settingsPath)).initializationCompleted, "completion must persist")
                    root.reopen()
                } else if (root.stage === 15) {
                    root.check(loader.sourceComponent === Constants.pageOnStart && !root.appWindow.initializing, "subsequent launches must skip setup")
                    root.check(Colors.colorScheme === "glacier", "chosen theme must persist")
                    console.log("INITIALIZATION_UI_SMOKE_PASSED", INITIALIZATION_TEST_MODE)
                    stop()
                    Qt.quit()
                }
                root.stage++
            } catch (error) {
                console.error("INITIALIZATION_UI_SMOKE_FAILED", error)
                stop()
                Qt.exit(1)
            }
        }
    }
}
