import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    width: 1000; height: 1040; visible: true
    color: Colors.background_n
    XCFile { id: files }
    SettingsBuildKits { id: settings; anchors.fill: parent; anchors.margins: 20 }
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
        BuildKits.kitsPath = SMOKE_DIR + "/target"
        Colors.applyColorScheme("midnight")
    }
    Timer {
        interval: 500; running: true; repeat: true
        property int stage: 0
        onTriggered: {
            try {
                if (stage === 0) {
                    root.check(BuildKits.templates.length === 0, "empty catalog")
                    root.check(root.find(settings, "downloadBuildKits").enabled, "download available")
                    var source = SMOKE_DIR + "/incoming"
                    files.folder(source + "/templates")
                    files.folder(source + "/blueprints")
                    files.folder(source + "/materials/alpha")
                    root.check(files.write(source + "/templates/测试套件.xcshopT",
                        "89755dae-f798-440d-b3a9-342ee8a9070f\n0\n\"26.3\"...\n../blueprints/main.xcshoper\n../materials/alpha\n[\"套件介绍与依赖检查。\"]\n"), "template fixture")
                    root.check(files.write(source + "/blueprints/main.xcshoper", "build\n"), "blueprint fixture")
                    root.check(files.write(source + "/materials/alpha/sell.xcontent", "sell\n"), "material fixture")
                    BuildKits.acquire(source)
                    root.check(!root.find(settings, "downloadBuildKits").enabled, "download locked while importing")
                    stage = 1
                } else if (stage === 1 && !BuildKits.acquiring) {
                    root.check(BuildKits.templates.length === 1, BuildKits.acquisitionStatus)
                    root.check(settings.selectedTemplate.valid, "catalog selection refreshed")
                    root.check(root.find(settings, "downloadBuildKits").enabled, "download unlocked")
                    stage = 2
                    settings.grabToImage(function(result) { result.saveToFile(SMOKE_OUTPUT_DIR + "/build-kits-dark.png") })
                } else if (stage === 2) {
                    Colors.applyColorScheme("glacier")
                    root.width = 560
                    stage = 3
                } else if (stage === 3) {
                    stop()
                    settings.grabToImage(function(result) {
                        result.saveToFile(SMOKE_OUTPUT_DIR + "/build-kits-light-narrow.png")
                        console.log("BUILD_KITS_UI_SMOKE_PASSED")
                        Qt.quit()
                    })
                }
            } catch (error) {
                console.error("BUILD_KITS_UI_SMOKE_FAILED", error)
                Qt.exit(1)
            }
        }
    }
}
