pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    width: 1000; height: 760; visible: true
    property int stage: 0
    property int ticks: 0
    property int backEvents: 0
    property bool sawEntrance: false
    PageOnSettings {
        id: settings
        anchors.fill: parent
        onPageEvent: function(type, parameters) { if (type === "Settings.back") root.backEvents++ }
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) { var match = find(child, name); if (match) return match }
        return null
    }
    function nav(item, text) {
        if (item instanceof SettingsNavButton && item.text === text) return item
        for (var child of item.children) { var match = nav(child, text); if (match) return match }
        return null
    }
    Component.onCompleted: {
        Global.settingsPath = SMOKE_DIR + "/settings.json"
        Global.animationSpeed = 1
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            try {
                root.check(++root.ticks < 100, "timed out at stage " + root.stage)
                var loader = root.find(settings, "settingsSectionLoader")
                var motion = root.find(settings, "settingsSectionTransition")
                if (root.stage === 0) {
                    if (settings.opacity < 1) return
                    var previous = loader.item
                    UiInput.click(root.nav(settings, "构建套件"))
                    root.check(settings.currentSection === 1 && settings.displayedSection === 0
                               && motion.running && loader.item === previous, "keep old content during exit")
                    root.check(motion.activeExitDuration === 500 && motion.activeEnterDuration === 500, "500ms fade durations")
                    root.stage++
                } else if (root.stage === 1) {
                    root.check(motion.contentOpacity > 0 && motion.contentOpacity < 1 && motion.contentOffset === 0, "fade out in place")
                    UiInput.click(root.nav(settings, "构建器"))
                    UiInput.click(root.nav(settings, "物品信息"))
                    root.check(settings.currentSection === 3 && settings.displayedSection === 0, "sidebar remains responsive")
                    root.stage++
                } else if (root.stage === 2) {
                    if (motion.running) return
                    root.check(settings.displayedSection === 3 && loader.item.itemsRootPath.length > 0, "last selected category must win")
                    root.check(loader.opacity === 1 && motion.contentOffset === 0, "transition restores content")
                    Global.animationSpeed = 2
                    root.stage++
                } else if (root.stage === 3) {
                    UiInput.click(root.nav(settings, "构建器"))
                    root.check(motion.tempo === 2 && motion.running, "honor configured animation speed")
                    root.stage++
                } else if (root.stage === 4) {
                    if (settings.displayedSection === 2 && motion.contentOpacity > 0 && motion.contentOpacity < 1
                            && motion.contentOffset > 0) root.sawEntrance = true
                    if (motion.running) return
                    root.check(root.sawEntrance && settings.displayedSection === 2, "fade in while moving upward")
                    root.check(loader.opacity === 1 && motion.contentOffset === 0, "release input after entry")
                    settings.currentSection = 0
                    root.stage++
                } else if (root.stage === 5) {
                    if (motion.running) return
                    root.check(settings.displayedSection === 0 && loader.item.presetBackgrounds.length > 0, "return to interface settings")
                    settings.pageEvent("Settings.back", {})
                    root.check(root.backEvents === 1, "return navigation remains available")
                    console.log("SETTINGS_SECTIONS_UI_SMOKE_PASSED")
                    stop(); Qt.quit()
                }
            } catch (error) {
                console.error("SETTINGS_SECTIONS_UI_SMOKE_FAILED", error)
                stop(); Qt.exit(1)
            }
        }
    }
}
