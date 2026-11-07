pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    width: 800; height: 600
    property string project: SMOKE_DIR + "/current-format"
    XCFile { id: file }
    Component { id: cost; PageOnCost {} }
    Component { id: ui; PageOnUI {} }
    Component { id: items; SettingsItems {} }

    function check(value, message) { if (!value) throw new Error(message) }
    function readElement(component, kind, value, supported) {
        Global.current_element = kind
        Global.set_file([], "format")
        var path = project + "/" + kind + "/format.xcse" + kind
        var original = typeof value === "string" ? value : JSON.stringify(value)
        check(file.writeAtomic(path, original), "Write element fixture")
        var page = component.createObject(root.contentItem, {visible: false, width: 800, height: 600})
        check(page, component.errorString())
        check(page.dataLoaded === supported, "Unexpected format acceptance for " + kind)
        if (!supported) {
            check(page.dataError.length > 0, "Unsupported format has no error")
            check(file.read(path) === original, "Unsupported format was rewritten")
        }
        page.destroy()
    }
    Timer {
        interval: 40; running: true
        onTriggered: {
            try {
                Global.animationSpeed = 20
                Global.project_location = root.project
                file.folder(root.project + "/Cost")
                file.folder(root.project + "/UI")
                root.readElement(cost, "Cost", {display: "代价", type: {kind: "item_count", value: "minecraft:stone", filter: false}}, true)
                root.readElement(cost, "Cost", {display: "旧代价", type: {selected: 1, value: "minecraft:stone", filter: false}}, false)
                root.readElement(ui, "UI", {containerType: "generic_9x3", slots: [], nestedGroups: []}, true)
                root.readElement(ui, "UI", {containerType: "generic_9x3", slots: [[{element: "Item/stone.xcseItem"}]], nestedGroups: []}, false)
                root.readElement(ui, "UI", {containerType: "generic_9x3", slots: [{items: []}], nestedGroups: []}, false)
                root.readElement(ui, "UI", "", false)

                check(file.writeAtomic(APP_DIRPATH + "/settings.json", JSON.stringify({
                    backgroundMode: "imageBlur", themeColor: {r: 1, g: 0, b: 0, a: 1}
                })), "Write settings fixture")
                Colors.setThemeColor("#123456")
                Global.loadSettings()
                check(Global.backgroundMode === "color", "Old background mode was migrated")
                check(Qt.colorEqual(Colors.themeColor, "#123456"), "Old colour object was restored")
                check(file.writeAtomic(APP_DIRPATH + "/settings.json", JSON.stringify({
                    backgroundMode: "image", themeColor: "#abcdef"
                })), "Write current settings")
                Global.loadSettings()
                check(Global.backgroundMode === "image" && Qt.colorEqual(Colors.themeColor, "#abcdef"),
                      "Current settings failed to load")

                var itemsRoot = APP_DIRPATH + "/assets/minecraft/items"
                check(file.writeAtomic(itemsRoot + "/items.json", '[{"name":"minecraft:stone"}]'), "Write old item list")
                var settingsPage = items.createObject(root.contentItem, {visible: false})
                check(settingsPage && settingsPage.items.length === 0, "Old item list was loaded")
                settingsPage.destroy()
                console.log("CURRENT_FORMAT_UI_SMOKE_PASSED")
                Qt.exit(0)
            } catch (error) {
                console.error("CURRENT_FORMAT_UI_SMOKE_FAILED: " + error)
                Qt.exit(1)
            }
        }
    }
}
