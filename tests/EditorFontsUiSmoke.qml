import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    width: 1100; height: 900; visible: true
    color: Colors.background_n
    property int step: 0
    XCFile { id: files }
    PageOnSettings { id: settings; anchors.fill: parent }
    XCTextField { id: existingField; visible: false; text: "中文 ABC 012 {}"; highlightMacros: true }
    XCTextArea { id: existingArea; visible: false; editorFontSize: 12 }

    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var i = 0; i < item.children.length; ++i) {
            var found = find(item.children[i], name)
            if (found) return found
        }
        return null
    }
    function checkFont(control, latin, chinese) {
        var actualLatin = UiInput.renderedFontFamilies(control.font, "Abc019_{}[]!/+=$").join()
        var actualChinese = UiInput.renderedFontFamilies(control.font, "中文商店钻石").join()
        check(actualLatin === latin, control + ": expected Latin " + latin + ", got " + actualLatin)
        check(actualChinese === chinese, control + ": expected Chinese " + chinese + ", got " + actualChinese)
    }
    Component.onCompleted: Global.settingsPath = SMOKE_DIR + "/settings.json"

    Timer {
        interval: 900; running: true; repeat: true
        onTriggered: {
            try {
                var chinese = root.find(settings, "editorChineseFontPicker")
                var latin = root.find(settings, "editorLatinFontPicker")
                root.check(chinese && latin && settings.currentSection === 0, "fonts in interface settings")
                root.check(settings.sections.length === 4, "no separate fonts navigation")
                root.check(!root.find(settings, "editorFontPreviewField")
                           && !root.find(settings, "editorFontPreviewArea"), "no font preview")
                if (root.step === 0) {
                    var card = root.find(settings, "editorFontSettings")
                    for (var viewport = card.parent; viewport; viewport = viewport.parent) {
                        if (viewport.contentY !== undefined && viewport.contentItem) {
                            viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height,
                                                                   card.mapToItem(viewport.contentItem, 0, 0).y))
                            break
                        }
                    }
                    root.checkFont(existingField, "Consolas", "Microsoft YaHei")
                    root.checkFont(existingArea, "Consolas", "Microsoft YaHei")
                    // These test fonts are loaded explicitly for the offscreen platform.
                    chinese.valueActivated("SimSun")
                    root.checkFont(existingField, "Consolas", "SimSun")
                    root.checkFont(existingArea, "Consolas", "SimSun")
                    latin.valueActivated("Segoe UI")
                    root.check(Global.editorLatinFont === "Segoe UI", "font selector activation")
                    root.checkFont(existingField, "Segoe UI", "SimSun")
                    root.checkFont(existingArea, "Segoe UI", "SimSun")
                    root.check(existingArea.font.pixelSize === 12, "font size override preserved")
                    var saved = JSON.parse(files.read(Global.settingsPath))
                    root.check(saved.editorLatinFont === "Segoe UI" && saved.editorChineseFont === "SimSun", "font persistence")
                    Global.editorLatinFont = "Consolas"
                    Global.loadSettings()
                    root.check(Global.editorLatinFont === "Segoe UI", "saved font reload")
                    root.check(Global.editorChineseFont === "SimSun", "saved Chinese font reload")
                    UiInput.click(root.find(settings, "resetEditorFonts"))
                    root.checkFont(existingField, "Consolas", "Microsoft YaHei")
                    root.check(JSON.parse(files.read(Global.settingsPath)).editorLatinFont === "Consolas", "reset persisted")
                    root.step++
                    return
                }
                root.check(chinese.width > 300 && latin.width > 300, "font picker layout")
                if (root.step === 1) {
                    root.step++
                    settings.grabToImage(function(result) {
                        result.saveToFile(SMOKE_OUTPUT_DIR + "/editor-font-settings-dark.png")
                        Colors.applyColorScheme("parchment")
                    })
                    return
                }
                settings.grabToImage(function(result) {
                    result.saveToFile(SMOKE_OUTPUT_DIR + "/editor-font-settings-light.png")
                    console.log("EDITOR_FONTS_UI_SMOKE_PASSED")
                    Qt.quit()
                })
                stop()
            } catch (error) {
                console.error("EDITOR_FONTS_UI_SMOKE_FAILED", error)
                Qt.exit(1)
            }
        }
    }
}
