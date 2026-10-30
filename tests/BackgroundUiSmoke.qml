import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    width: 1060; height: 1100; visible: true
    color: Colors.background_n
    XCFile { id: files }
    SettingsInterface { id: settings; anchors.fill: parent }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var i = 0; i < item.children.length; ++i) {
            var found = find(item.children[i], name)
            if (found) return found
        }
        return null
    }
    Component.onCompleted: {
        Global.settingsPath = SMOKE_DIR + "/settings.json"
        Global.backgroundMode = "image"
    }
    Timer {
        interval: 1400; running: true; repeat: true
        property string imported: ""
        onTriggered: {
            try {
                if (!imported.length) {
                root.check(settings.presetBackgrounds.length === 6, "preset count")
                for (var i = 0; i < settings.presetBackgrounds.length; ++i) {
                    var preset = settings.presetBackgrounds[i]
                    var card = root.find(settings, "backgroundCard_" + preset.name)
                    root.check(card !== null && card.height > 100, "preset layout")
                    for (var j = 0; j < preset.schemes.length; ++j) {
                        card.themeChosen(preset.schemes[j])
                        root.check(Colors.colorScheme === preset.schemes[j], "recommended theme")
                        root.check(Colors.themeColor.toString() === (Colors.accentForColorScheme(preset.schemes[j]) || Colors.accentChoices[0]), "recommended accent")
                        root.check(Global.backgroundImage === card.imageSource, "preset selection")
                    }
                }
                // Copy a real PNG out of resources to exercise local-file import.
                var source = SMOKE_DIR + "/自定义背景.png"
                root.check(files.copy(":/assets/backgrounds/朝阳.png", source), "fixture copy")
                settings.importBackground(source)
                imported = Global.backgroundImage
                root.check(imported.indexOf("file:") === 0, "owned image URL")
                root.check(decodeURI(imported).indexOf(files.runtimePath() + "/backgrounds/") >= 0, "runtime storage")
                root.check(files.exists(source), "original preserved")
                root.check(!files.removeBackgroundImage(source), "original deletion rejected")
                root.check(files.backgroundImages().some(function(entry) { return entry.source === imported }), "library scan")
                root.check(files.read(Global.settingsPath).indexOf(imported) >= 0, "selection persisted")
                return // Let the asynchronous thumbnail finish reading before deletion.
                }
                stop()
                settings.removeBackground(imported)
                root.check(!files.exists(imported), "owned copy removed")
                root.check(Global.backgroundImage === "qrc:/assets/backgrounds/朝阳.png", "active deletion fallback")
                files.write(SMOKE_DIR + "/invalid.png", "invalid")
                root.check(files.importBackgroundImage(SMOKE_DIR + "/invalid.png") === "", "invalid image rejected")
                Colors.applyColorScheme("parchment")
                settings.grabToImage(function(result) {
                    result.saveToFile(SMOKE_OUTPUT_DIR + "/background-settings-smoke.png")
                    console.log("BACKGROUND_UI_SMOKE_PASSED")
                    Qt.quit()
                })
            } catch (error) {
                if (imported.length) files.removeBackgroundImage(imported)
                console.error("BACKGROUND_UI_SMOKE_FAILED", error)
                Qt.exit(1)
            }
        }
    }
}
