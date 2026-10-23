pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    width: 1180
    height: 920
    color: Colors.background
    property var page: null
    property int step: 0
    property bool wideCaptured: false
    property bool narrowCaptured: false
    property bool advancedCaptured: false
    property bool pickerCaptured: false
    property bool switchCaptured: false
    readonly property var versions: [
        {id: "26.3", type: "release", label: "26.3"},
        {id: "26.3-snapshot-7", type: "snapshot", label: "26.3-snapshot-7 · 测试版"},
        {id: "1.13", type: "release", label: "1.13"}
    ]
    XCFile { id: file }
    Component { id: settings; SettingsItems {} }
    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: 24
        color: Colors.transparent
        NumberAnimation on opacity { from: 0.999; to: 1; duration: 500; loops: Animation.Infinite }
    }
    function check(condition, message) { if (!condition) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        if (!item.children) return null
        for (var i = 0; i < item.children.length; ++i) {
            var found = find(item.children[i], name)
            if (found) return found
        }
        return null
    }
    Component.onCompleted: {
        Global.loadSettings()
        var base = APP_DIRPATH + "/assets/minecraft/items"
        var relative = "packs/" + "a".repeat(40) + "-r2-1234"
        var catalog = {schemaVersion: 2, gameVersion: "1.13", itemCount: 3, rendered: 1, approximate: 1, missing: 1,
            items: [{name: "minecraft:stone", iconStatus: "rendered"},
                    {name: "minecraft:shield", iconStatus: "approximate", iconReason: "特殊模型预览"},
                    {name: "minecraft:future_item", iconStatus: "missing", iconReason: "未知模型"}]}
        check(file.writeAtomic(base + "/" + relative + "/catalog.json", JSON.stringify(catalog)), "Write catalog")
        var other = "packs/" + "b".repeat(40) + "-r2-5678"
        check(file.writeAtomic(base + "/" + other + "/catalog.json", JSON.stringify({schemaVersion: 2, gameVersion: "1.21.4", itemCount: 1, rendered: 1, approximate: 0, missing: 0,
            items: [{name: "minecraft:stone", iconStatus: "rendered"}]})), "Write second imported version")
        check(file.copy(":/assets/gui/element/Item.png", base + "/" + other + "/assets/minecraft/stone.png"), "Copy second version icon")
        check(file.writeAtomic(base + "/active.json", JSON.stringify({schemaVersion: 2, pack: relative})), "Write active pointer")
        check(file.writeAtomic(base + "/custom-items.json", JSON.stringify([{itemId: "example:test"}])), "Write custom items")
        check(file.copy(":/assets/gui/element/Item.png", base + "/" + relative + "/assets/minecraft/stone.png"), "Copy vanilla icon")
        check(file.copy(":/assets/gui/element/Item.png", base + "/" + relative + "/assets/minecraft/shield.png"), "Copy preview icon")
        check(file.copy(":/assets/gui/element/Item.png", base + "/assets/example/test.png"), "Copy custom icon")
        page = settings.createObject(frame, {width: frame.width, height: frame.height})
        check(page, settings.errorString())
        page.width = Qt.binding(function() { return frame.width })
        page.height = Qt.binding(function() { return frame.height })
    }
    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            try {
                if (root.step === 0) {
                    root.check(root.page.currentVersion === "1.13", "Active game version")
                    root.check(root.page.items.length === 4, "Vanilla and custom entries")
                    root.check(Global.getItemTexturePath("minecraft:stone").indexOf("/packs/") >= 0, "Versioned icon path")
                    root.check(Global.getItemTexturePath("example:test").indexOf("/packs/") < 0, "Independent custom icon")
                    root.check(root.page.width > 0 && root.page.height > 0, "Settings page has visible geometry")
                    root.check(root.find(root.page, "minecraftLocalForm").visible, "Local import is the default")
                    root.check(!root.find(root.page, "minecraftVersionField").visible, "Local import hides the online version picker")
                    root.check(!root.find(root.page, "minecraftJavaField").visible, "Automatic settings are collapsed")
                    root.page.onlineVersion = "26.3"
                    root.check(root.page.importOptions().version === "", "Local import ignores a saved online version")
                    root.find(root.page, "minecraftDownloadSourceButton").clicked()
                    root.check(root.find(root.page, "minecraftVersionField").visible, "Online import shows version selection")
                    root.check(root.page.importOptions().sourcePath === "", "Online import never uses a saved local path")
                    root.check(root.page.importOptions().version === "26.3", "Online import uses the chosen version")
                    root.find(root.page, "minecraftLocalSourceButton").clicked()
                    root.check(root.page.grabToImage(function(result) {
                        root.wideCaptured = result.saveToFile(SMOKE_OUTPUT_DIR + "/minecraft-settings-preview.png")
                    }), "Request wide screenshot")
                    root.page.filter = 3
                    root.page.filterItems()
                    root.check(root.page.filteredItems.length === 1, "Approximate filter")
                    root.page.filter = 4
                    root.page.filterItems()
                    root.check(root.page.filteredItems.length === 1, "Missing filter")
                    root.page.filter = 0
                    root.page.filterItems()
                } else if (root.step === 1) {
                    root.check(root.wideCaptured, "Save wide screenshot")
                    root.find(root.page, "minecraftAdvancedButton").clicked()
                    root.check(root.find(root.page, "minecraftJavaField").visible, "Advanced Java path is accessible")
                    root.check(root.find(root.page, "minecraftLibrariesField").visible, "Advanced libraries path is accessible")
                    root.find(root.page, "minecraftNetworkCheck").checked = false
                    root.check(root.page.importOptions().allowNetwork === false, "Offline choice reaches the importer")
                    root.find(root.page, "minecraftNetworkCheck").checked = true
                } else if (root.step === 2) {
                    root.check(root.page.grabToImage(function(result) {
                        root.advancedCaptured = result.saveToFile(SMOKE_OUTPUT_DIR + "/minecraft-settings-advanced.png")
                    }), "Request advanced screenshot")
                } else if (root.step === 3) {
                    root.check(root.advancedCaptured, "Save advanced screenshot")
                    root.find(root.page, "minecraftAdvancedButton").clicked()
                    root.page.width = 620
                } else if (root.step === 4) {
                    root.check(root.page.grabToImage(function(result) {
                        root.narrowCaptured = result.saveToFile(SMOKE_OUTPUT_DIR + "/minecraft-settings-narrow.png")
                    }), "Request narrow screenshot")
                } else if (root.step === 5) {
                    root.check(root.narrowCaptured, "Save narrow screenshot")
                    root.page.destroy()
                    root.page = settings.createObject(frame, {width: frame.width, height: frame.height})
                    root.check(root.page && root.page.items.length === 4, "Page recreation preserves active catalog")
                    root.page.versionCatalog = root.versions
                    root.check(root.page.pickerVersions.length === 2, "Hide snapshots by default")
                    root.page.showSnapshots = true
                    root.check(root.page.pickerVersions.length === 3, "Show snapshot versions")
                    root.find(root.page, "minecraftDownloadSourceButton").clicked()
                    root.find(root.page, "minecraftVersionPickerButton").clicked()
                } else if (root.step === 6) {
                    root.check(root.find(root.contentItem, "minecraftVersionChoice_1.13"), "Historical version choice is visible")
                    root.check(root.contentItem.grabToImage(function(result) {
                        root.pickerCaptured = result.saveToFile(SMOKE_OUTPUT_DIR + "/minecraft-version-picker.png")
                    }), "Request version picker screenshot")
                } else if (root.step === 7) {
                    root.check(root.pickerCaptured, "Save version picker screenshot")
                    root.find(root.contentItem, "minecraftVersionChoice_1.13").clicked()
                    root.check(root.find(root.page, "minecraftVersionField").text === "1.13", "Select historical version")
                    root.find(root.page, "minecraftLocalSourceButton").clicked()
                    root.check(root.page.importOptions().version === "", "Switching back to local cannot reuse the online version")
                    root.check(file.writeAtomic(APP_DIRPATH + "/local-game/client.jar", "legacy fixture"), "Write local client fixture")
                    root.check(file.writeAtomic(APP_DIRPATH + "/local-game/client.json", JSON.stringify({id: "1.13", mainClass: "net.minecraft.client.main.Main"})), "Write legacy version metadata")
                    root.find(root.page, "minecraftLocalPathField").text = APP_DIRPATH + "/local-game/client.jar"
                } else if (root.step === 8) {
                    root.check(!MinecraftAssetImporter.inspectingLocal && root.page.localInfo.ok === true, "Local inspection completes asynchronously")
                    root.check(root.page.localInfo.version === "1.13", "Local file version is detected without the online catalog")
                    root.check(root.find(root.page, "minecraftImportButton").enabled, "Detected local file can be imported")
                    root.check(root.page.importOptions().version === "", "Detected local version is never supplied as an online selection")
                    root.find(root.page, "minecraftSwitchVersionButton").clicked()
                    root.check(root.page.importedVersions.length === 2, "Imported version list comes from completed packs")
                } else if (root.step === 9) {
                    root.check(!root.find(root.contentItem, "minecraftImportedChoice_1.13").enabled, "Current imported version is marked")
                    root.check(root.contentItem.grabToImage(function(result) {
                        root.switchCaptured = result.saveToFile(SMOKE_OUTPUT_DIR + "/minecraft-switch-version.png")
                    }), "Request imported version picker screenshot")
                } else if (root.step === 10) {
                    root.check(root.switchCaptured, "Save imported version picker screenshot")
                    root.find(root.contentItem, "minecraftImportedChoice_1.21.4").clicked()
                    root.check(root.page.currentVersion === "1.21.4", "Switch reloads current catalog")
                    root.check(root.page.items.length === 2, "Custom entries survive switching")
                    root.check(Global.getItemTexturePath("minecraft:stone").indexOf("b".repeat(40)) >= 0, "Editor icon lookup uses newly active pack")
                    root.find(root.page, "minecraftSwitchVersionButton").clicked()
                } else {
                    root.find(root.contentItem, "minecraftImportedChoice_1.13").clicked()
                    root.check(root.page.currentVersion === "1.13" && root.page.items.length === 4, "Previous version can be reapplied")
                    console.log("MINECRAFT_ITEMS_UI_SMOKE_PASSED")
                    Qt.quit()
                }
                root.step += 1
            } catch (error) { console.error(error); Qt.exit(1) }
        }
    }
}
