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
    property bool advancing: false
    readonly property string itemsRoot: APP_DIRPATH + "/assets/minecraft/items"
    readonly property string pack: "packs/" + "a".repeat(40) + "-r1-abc"
    readonly property bool hasUpdate: INITIALIZATION_TEST_MODE === "update"
    readonly property bool slowCheck: INITIALIZATION_TEST_MODE === "skip"
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
        var transition = find(appWindow.contentItem, "initializationStepTransition")
        for (var attempt = 0; transition && transition.running && attempt < 100; ++attempt)
            UiInput.settle(20)
        check(!transition || !transition.running, "step transition must finish")
        var target = find(appWindow.contentItem, name)
        check(target && target.visible && target.enabled, "unavailable action " + name)
        UiInput.click(target)
    }
    function capture(name) {
        // Capture the page directly; software rendering cannot draw the window's GPU mask.
        var captured = false
        var saved = false
        var started = find(appWindow.contentItem, "mainPageLoader").item.grabToImage(function(result) {
            saved = result.saveToFile(SMOKE_OUTPUT_DIR + "/initialization-" + INITIALIZATION_TEST_MODE + "-" + name + ".png")
            captured = true
        })
        for (var attempt = 0; started && !captured && attempt < 50; ++attempt) UiInput.settle(20)
        check(started && captured && saved, "capture must finish before advancing: " + name)
    }
    function checkAttachedThemes(page, dark) {
        var picker = find(page, "initializationThemePicker")
        var divider = find(page, "initializationThemeDivider")
        for (var scheme of picker.themes) {
            var card = find(page, "initializationTheme_" + scheme.id)
            var edgeX = dark ? 0 : card.width
            var top = divider.mapFromItem(card, edgeX, 0)
            var bottom = divider.mapFromItem(card, edgeX, card.height)
            var gap = dark ? Math.min(top.x, bottom.x) : -Math.max(top.x, bottom.x)
            check(gap >= 3 && gap <= 10, "theme card must hug the slanted divider: " + scheme.id)
            var mask = find(card, "initializationThemeEntranceMask_" + scheme.id)
            check(mask && mask.clip, "entrance must retain a divider-side mask: " + scheme.id)
            var hidden = mask.mapFromItem(card, dark ? -1 : card.width + 1, card.height / 2)
            var rebound = mask.mapFromItem(card, dark ? card.width + 16 : -16, card.height / 2)
            check(!mask.contains(hidden), "entrance must stay hidden behind the divider: " + scheme.id)
            check(mask.contains(rebound), "outer edge must have room for the rebound: " + scheme.id)
        }
    }
    function skipSlowCheck(page) {
        var skip = find(page, "initializationSkipUpdateCheck")
        if (!skip.visible) return false
        check(Updates.checking, "slow request must still be running before skip")
        click("initializationSkipUpdateCheck")
        check(page.checkComplete && page.updateCheckSkipped && !Updates.checking, "skip must stop waiting and cancel the request")
        check(find(page, "initializationWelcomeStatus").text === "点击任意位置开始", "skip must show start text")
        check(page.step === "welcome" && !skip.visible, "skip must stay on the welcome page until another click")
        return true
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
        reopen()
        var page = find(appWindow.contentItem, "mainPageLoader").item
        check(page && page.step === "welcome" && !page.checkComplete, "first launch must wait for checking")
        check(!find(page, "initializationSkipUpdateCheck").visible, "skip must start hidden")
        page.begin()
        check(page.step === "welcome", "checking must block start")
    }
    Timer {
        interval: 400; running: true; repeat: true
        onTriggered: {
            if (root.advancing) return
            root.advancing = true
            try {
                if (++root.ticks > 65) throw new Error("timed out at stage " + root.stage)
                var loader = root.find(root.appWindow.contentItem, "mainPageLoader")
                var page = loader.item
                var stepTransition = root.find(page, "initializationStepTransition")
                if (stepTransition && stepTransition.running) return
                root.check(!root.find(root.appWindow.contentItem, "updateNotice"), "onboarding must own update notice")
                if (root.stage === 0) {
                    if (root.slowCheck && !page.checkComplete) {
                        if (root.ticks <= 3) root.check(!root.find(page, "initializationSkipUpdateCheck").visible, "skip must not appear before two seconds")
                        if (!root.skipSlowCheck(page)) return
                    }
                    if (!page.checkComplete) return
                    root.check(root.appWindow.initializing && loader.sourceComponent === Constants.pageOnInitialize, "first launch route")
                    root.check(root.find(root.appWindow.contentItem, "windowTitle").text === "", "welcome must hide the title text")
                    var controls = root.find(root.appWindow.contentItem, "windowControls")
                    var revealArea = root.find(root.appWindow.contentItem, "windowControlRevealArea")
                    root.check(controls.opacity === 0 && !controls.enabled, "welcome controls must start hidden")
                    UiInput.hover(revealArea)
                    UiInput.settle(250)
                    root.check(controls.opacity === 1 && controls.enabled, "nearby pointer must reveal window controls")
                    UiInput.hover(controls)
                    UiInput.settle(50)
                    root.check(controls.opacity === 1, "controls must stay visible while hovered")
                    UiInput.hover(revealArea, false)
                    UiInput.settle(250)
                    root.check(controls.opacity === 0 && !controls.enabled, "controls must hide after pointer leaves")
                    root.check(loader.x === 0 && page.x === 0 && page.width === root.appWindow.surfaceWidth, "full window layout")
                    root.capture("welcome")
                } else if (root.stage === 1) {
                    root.click("initializationWelcomeAction")
                    root.check(page.step === (root.hasUpdate ? "update" : "theme"), "update branch")
                    root.check(page.displayedStep === "welcome", "welcome remains until fade-out finishes")
                    root.check(root.find(page, "initializationStepTransition").running, "welcome transition must animate")
                    UiInput.settle(35)
                    var welcomeMotion = root.find(page, "initializationStepTransition")
                    root.check(welcomeMotion.activeExitDuration === 500 && welcomeMotion.activeEnterDuration === 500, "welcome fades must use 500ms")
                    root.check(welcomeMotion.contentOpacity > 0 && welcomeMotion.contentOpacity < 1
                               && welcomeMotion.contentOffset === 0, "welcome must fade out in place")
                } else if (root.stage === 2) {
                    if (root.hasUpdate) {
                        root.capture("update")
                        root.click("initializationViewUpdate")
                        root.check(UpdateFixture.openedCount() === 1, "update browser action")
                        root.click("initializationNext")
                        UiInput.settle(35)
                        var updateMotion = root.find(page, "initializationStepTransition")
                        root.check(updateMotion.activeExitDuration === 500 && updateMotion.activeEnterDuration === 500, "update fades must use 500ms")
                        root.check(updateMotion.contentOpacity > 0 && updateMotion.contentOpacity < 1
                                   && updateMotion.contentOffset === 0, "update must fade out in place")
                    }
                    root.check(page.step === "theme", "theme must follow welcome/update")
                    root.capture("theme-dark")
                } else if (root.stage === 3) {
                    root.check(root.find(root.appWindow.contentItem, "windowTitle").text === "Minecraft xcshop", "later steps must restore the title text")
                    root.check(root.find(root.appWindow.contentItem, "windowControls").opacity === 1, "later steps must keep window controls visible")
                    var picker = root.find(page, "initializationThemePicker")
                    var next = root.find(page, "initializationNext")
                    var darkMode = root.find(page, "initializationMode_dark")
                    var lightMode = root.find(page, "initializationMode_light")
                    var divider = root.find(page, "initializationThemeDivider")
                    root.check(darkMode.visible && lightMode.visible && !picker.expanded, "start with two transparent mode choices")
                    root.check(!root.find(page, "initializationTheme_midnight") && !next.enabled && !next.visible, "themes and navigation must wait for a mode")
                    root.check(divider.rotation !== 0 && divider.height < picker.height * 0.7, "divider must be slanted and shorter than the window")
                    var shadow = root.find(page, "initializationThemeDividerShadow")
                    root.check(shadow.y < 0 && shadow.height > divider.height, "shadow needs padding beyond both line ends")
                    page.next()
                    root.check(page.step === "theme", "direct navigation must require an explicit theme")
                    UiInput.hover(darkMode)
                    UiInput.settle(360)
                    UiInput.hover(lightMode)
                    UiInput.settle(160)
                    root.check(Colors.colorScheme === "cloud" && !picker.selectedTheme.length, "light hover must preview cloud without selecting")
                    root.check(!root.find(page, "initializationThemeRipple"), "hover must not use a circular reveal")
                    root.check(!Qt.colorEqual(Colors.background_n, "#1b1d27") && !Qt.colorEqual(Colors.background_n, "#dce2eb"), "hover must interpolate the background color")
                    UiInput.hover(darkMode)
                    UiInput.settle(160)
                    root.check(Colors.colorScheme === "midnight", "rapid reversal must preview midnight")
                    root.click("initializationMode_dark")
                    UiInput.settle(460)
                    root.check(!lightMode.visible && divider.x < picker.width * 0.4, "dark selection must shrink to the left")
                    root.check(root.find(page, "initializationTheme_midnight") && !root.find(page, "initializationTheme_cloud"), "show only dark palettes")
                    root.check(next.visible && !next.enabled, "mode preview cannot enable next")
                    var firstTheme = root.find(page, "initializationTheme_midnight")
                    var lastTheme = root.find(page, "initializationTheme_rose")
                    root.check(firstTheme.reveal > lastTheme.reveal, "themes must reveal from top to bottom")
                    UiInput.settle(850)
                    root.checkAttachedThemes(page, true)
                    root.capture("theme-dark-expanded")
                    var accents = root.find(page, "initializationAccentPicker")
                    root.check(!accents.visible, "accent buttons must wait for an explicit neutral-theme selection")
                    root.click("initializationTheme_midnight")
                    UiInput.settle(280)
                    root.check(accents.visible && accents.enabled, "midnight must reveal accent buttons")
                    root.click("initializationAccent_1")
                    root.check(Qt.colorEqual(Colors.themeColor, Colors.accentChoices[1]), "accent choice must update the live theme")
                    root.click("initializationThemeBack")
                    UiInput.settle(460)
                    root.click("initializationMode_light")
                    UiInput.settle(460)
                    root.check(picker.selectedTheme === "cloud" && accents.enabled, "cloud must also offer accent buttons")
                    root.check(Qt.colorEqual(Colors.themeColor, Colors.accentChoices[1]), "neutral counterparts must retain the chosen accent")
                    root.click("initializationAccent_3")
                    root.check(Qt.colorEqual(Colors.border, Colors.accentChoices[3]), "cloud must apply the chosen accent to controls")
                    root.click("initializationThemeBack")
                    UiInput.settle(460)
                    root.click("initializationMode_dark")
                    UiInput.settle(1350)
                    root.check(Qt.colorEqual(Colors.themeColor, Colors.accentChoices[3]), "switching back must preserve the neutral accent")
                    root.capture("theme-midnight-accent")
                    root.click("initializationTheme_violet")
                    root.check(next.enabled && Colors.colorScheme === "violet", "explicit dark theme must enable next")
                    root.check(!accents.enabled, "fixed-accent palettes must hide the accent controls")
                    root.click("initializationThemeBack")
                    UiInput.settle(460)
                    root.check(darkMode.visible && lightMode.visible && !next.enabled && !picker.selectedTheme.length, "back must restore mode choices and clear confirmation")
                    root.check(Colors.colorScheme === "violet", "return must retain the chosen dark theme")
                    root.check(Math.abs(divider.x - picker.width / 2) < 1, "back must recenter divider")
                    root.click("initializationMode_dark")
                    UiInput.settle(460)
                    root.check(Colors.colorScheme === "violet" && picker.selectedTheme === "violet" && next.enabled, "reopening the same mode must restore its selected theme")
                    root.click("initializationThemeBack")
                    UiInput.settle(460)
                    UiInput.hover(lightMode)
                    UiInput.settle(160)
                    root.check(Colors.colorScheme === "lavender", "light preview must use the counterpart of violet")
                    UiInput.hover(darkMode)
                    UiInput.settle(160)
                    root.check(Colors.colorScheme === "violet", "switching back must restore violet")
                    root.click("initializationMode_light")
                    UiInput.settle(1350)
                    root.check(!darkMode.visible && divider.x > picker.width * 0.6, "light selection must shrink to the right")
                    root.check(root.find(page, "initializationTheme_cloud") && !root.find(page, "initializationTheme_midnight"), "show only light palettes")
                    root.check(Colors.colorScheme === "lavender" && picker.selectedTheme === "lavender" && next.enabled, "switching modes must select the paired theme after an explicit choice")
                    root.checkAttachedThemes(page, false)
                    root.click("initializationTheme_glacier")
                    root.check(Colors.colorScheme === "glacier", "live theme preview")
                    root.click("initializationThemeBack")
                    UiInput.settle(460)
                    root.check(Colors.colorScheme === "glacier", "return must retain the chosen light theme")
                    UiInput.hover(darkMode)
                    UiInput.settle(160)
                    root.check(Colors.colorScheme === "slate", "dark preview must use the counterpart of glacier")
                    root.click("initializationMode_light")
                    UiInput.settle(1350)
                    root.check(Colors.colorScheme === "glacier" && picker.selectedTheme === "glacier" && next.enabled, "switching to light again must restore glacier")
                    root.appWindow.width = root.appWindow.minimumWidth
                    root.appWindow.height = root.appWindow.minimumHeight
                } else if (root.stage === 4) {
                    root.checkAttachedThemes(page, false)
                    root.capture("theme-light-small")
                    root.click("initializationNext")
                    root.check(page.step === "templates", "template step")
                    root.check(JSON.parse(files.read(Global.settingsPath)).backgroundColor === "#d0e3ed", "save the final palette rather than an intermediate animation color")
                    root.check(!JSON.parse(files.read(Global.settingsPath)).initializationCompleted, "partial setup cannot mark complete")
                } else if (root.stage === 5) {
                    root.capture("templates")
                    root.reopen()
                } else if (root.stage === 6) {
                    if (root.slowCheck && !page.checkComplete && !root.skipSlowCheck(page)) return
                    if (!page.checkComplete) return
                    root.check(page.step === "welcome" && root.appWindow.initializing, "interrupted setup must reopen")
                    root.check(Colors.colorScheme === "glacier", "restore chosen theme before hover preview")
                    root.click("initializationWelcomeAction")
                    if (root.hasUpdate) root.click("initializationNext")
                } else if (root.stage === 7) {
                    root.check(page.step === "theme" && !root.find(page, "initializationThemePicker").expanded, "reopened setup starts with mode choices")
                    root.check(!root.find(page, "initializationNext").enabled, "reopened setup must ask for an explicit choice")
                    root.click("initializationMode_light")
                    UiInput.settle(1350)
                    root.click("initializationTheme_glacier")
                    root.click("initializationNext")
                } else if (root.stage === 8) {
                    root.check(BuildKits.templates.length > 0 && BuildKits.templates[0].versions.length > 0, "bundled templates and coverage")
                    root.check(root.find(page, "initializationDownloadTemplates").enabled, "online acquisition entry")
                    root.click("initializationNext")
                } else if (root.stage === 9) {
                    root.check(page.step === "items" && page.mappedItems.length === 0 && page.missingIcons === 0, "fresh resource catalog must be empty")
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
                    page.loadMappings()
                    root.check(page.mappedItems.length === 0, "empty distribution")
                    root.click("initializationBack")
                    root.click("initializationNext")
                } else if (root.stage === 13) {
                    Global.settingsPath = APP_DIRPATH // Atomic write to a directory must fail.
                    root.click("initializationNext")
                    root.check(page.step === "items" && page.errorText.length > 0 && !Global.initializationCompleted, "save failure must preserve setup")
                    var entrance = root.find(root.appWindow.contentItem, "workspaceEntrance")
                    root.check(!entrance.busy, "save failure must not start the completion transition")
                    Global.settingsPath = APP_DIRPATH + "/settings.json"
                    root.click("initializationNext")
                    root.check(entrance.busy && entrance.destinationPage === Constants.pageOnStart, "completion must use the shared entrance animation")
                    root.check(loader.sourceComponent === Constants.pageOnInitialize, "initialization must remain visible until covered")
                    UiInput.settle(35)
                    root.check(entrance.veil > 0 && entrance.veil < 1 && entrance.contentOpacity < 1, "completion must fade through the shared veil")
                    root.click("initializationBack")
                    root.check(page.step === "items", "completion transition must block navigation input")
                    UiInput.settle(190)
                    root.check(loader.sourceComponent === Constants.pageOnStart && entrance.busy
                               && entrance.veil === 1 && entrance.reveal === 0, "switch to the start page only under the opaque veil")
                    root.check(!root.find(root.appWindow.contentItem, "mainPageTransition")
                               && !loader.item.animateEntrance && loader.item.opacity === 1,
                               "completion must not run a second page animation")
                } else if (root.stage === 14) {
                    var completedEntrance = root.find(root.appWindow.contentItem, "workspaceEntrance")
                    if (loader.sourceComponent !== Constants.pageOnStart || completedEntrance.busy) return
                    root.check(!root.appWindow.initializing && Global.initializationCompleted, "finish route")
                    root.check(completedEntrance.contentOpacity === 1 && completedEntrance.reveal === 1
                               && !completedEntrance.visible, "completion must finish revealing the start page and release input")
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
            } finally {
                root.advancing = false
            }
        }
    }
}
