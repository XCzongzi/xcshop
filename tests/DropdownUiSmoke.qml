pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    opacity: 0
    width: 1100; height: 760
    color: Colors.background_n
    property int step: 0
    property string plainValue: "first"
    property var modal: null
    property var lastResult: null
    property int contextRequests: 0
    property bool capturing: false
    property bool advancing: false
    property real previousPopupY: 0
    readonly property var simpleOptions: [{value: "first", label: "第一项"}, {value: "second", label: "第二项"}, {value: "third", label: "第三项"}]
    Component { id: projectDialog; PopupProjectSettings {} }
    Component { id: shopDialog; PopupShopSettings {} }
    Component { id: fadeDialog; PopupFrame {} }
    XCFileTreeBar { id: explorer; visible: false }
    Rectangle { id: flatBackdrop; width: root.width; height: root.height; color: "#202020"; visible: false }
    ContextMenu {
        id: menu
        menuItems: [{text: "更多操作", children: [{text: "子菜单操作"}]}, {text: "复制"}, {text: "重命名"}]
    }
    Connections { target: SignalBus; function onContextMenuRequested() { ++root.contextRequests } }
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Colors.background_n
        NumberAnimation on opacity { from: 0.999; to: 1; duration: 500; loops: Animation.Infinite }
        Repeater {
            model: 14
            Rectangle {
                required property int index
                x: index * 80; y: 260; width: 40; height: 200
                color: Colors.changeA(Colors.border, 0.22)
            }
        }
        Column {
            x: 24; y: 24; spacing: 12
            XCText { xcText: "项目选择控件"; onCenter: false; xcFontSize: 20 }
            XCTextField { id: before; width: 240; placeholderText: "Tab 从这里进入选择框" }
            XCComboBox {
                id: plain
                width: 240
                options: root.simpleOptions
                value: root.plainValue
                onValueActivated: function(value) { root.plainValue = value }
            }
            XCTextField { id: after; width: 240; placeholderText: "点击这里关闭下拉列表" }
        }
        ShopBar { id: shops; x: 480; y: 24; width: 480; contentHeight: 380; containerOptions: Constants.shopContainerOptions }
        Flickable {
            id: scroller
            x: 24; y: 460; width: 260; height: 180; contentHeight: 500; clip: true
            XCComboBox { id: moving; y: 100; width: 220; options: root.simpleOptions; value: "first" }
        }
        XCComboBox {
            id: edge
            x: parent.width - width - 12; y: parent.height - height - 12
            width: 160; compact: true; options: Constants.shopContainerOptions; value: "barrel"
        }
    }
    function check(condition, message) { if (!condition) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children || []) { var result = find(child, name); if (result) return result }
        return null
    }
    function insideWindow(combo) {
        var list = combo.popup.contentItem
        var point = list.mapToItem(null, 0, 0)
        check(point.x >= 0 && point.y >= 0 && point.x + list.width <= width + 1
              && point.y + list.height <= height + 1, "Popup escaped window bounds")
    }
    function checkFade(panel, label, closing) {
        var peak = 0
        for (var sample = 0; sample < 18; ++sample) {
            UiInput.settle(12)
            var brightness = UiInput.brightnessAt(panel, panel.width / 2, panel.height / 2)
            if (brightness < 0 && closing) break // Popup detached after its exit transition.
            check(brightness >= 0, "Could not capture an animation frame")
            peak = Math.max(peak, brightness)
        }
        console.log("DROPDOWN_FADE_PEAK " + label + ": " + peak)
        check(peak < 60, label + " flashed over a dark backdrop: " + peak)
    }
    function checkMenuLabels(item) {
        if (item.visible && item.xcText !== undefined)
            check(!item.truncated, "Context menu label was truncated: " + item.xcText)
        for (var child of item.children || []) checkMenuLabels(child)
    }
    function checkMenuExterior(path) {
        var panel = find(menu, "contextMenuSurface")
        var points = [Qt.point(1, 1), Qt.point(panel.width - 2, 1),
                      Qt.point(1, panel.height - 2), Qt.point(panel.width - 2, panel.height - 2),
                      Qt.point(panel.width / 2, -4), Qt.point(panel.width / 2, panel.height + 12)]
        for (var point of points) {
            var scene = panel.mapToItem(root.contentItem, point)
            var pixel = UiInput.imageColor(path, Math.round(scene.x * Screen.devicePixelRatio),
                                          Math.round(scene.y * Screen.devicePixelRatio))
            check(Math.max(pixel.r, pixel.g, pixel.b) * 255 <= 67,
                  "Solid menu material escaped the rounded panel at " + point)
        }
    }
    function checkDialogFades() {
        Global.mainWindow_popupBackdrop = flatBackdrop
        for (var cycle = 0; cycle < 2; ++cycle) {
            openDialog(fadeDialog, {manageVisibility: true})
            var panel = find(modal, "popupPanel")
            check(find(modal, "popupBackdropBlur").active === panel.blurEnabled,
                  "Modal backdrop blur must follow the renderer and the dialog lifecycle")
            checkFade(panel, "open " + cycle)
            modal.close(null)
            checkFade(panel, "close " + cycle)
            check(!find(modal, "popupBackdropBlur").active, "Backdrop blur remained active after closing")
        }
        modal.destroy(); modal = null
        UiInput.click(plain)
        check(plain.popup.visible, "Fade fixture dropdown did not open")
        checkFade(plain.popup.background, "dropdown open")
        plain.popup.close()
        checkFade(plain.popup.background, "dropdown close", true)
        Global.mainWindow_popupBackdrop = frame
    }
    function screenshot(name, done) {
        capturing = true
        UiInput.settle()
        contentItem.grabToImage(function(result) {
            check(result.saveToFile(SMOKE_OUTPUT_DIR + "/ui-dropdown-" + name + ".png"), "Save screenshot")
            root.capturing = false
            if (done) done(SMOKE_OUTPUT_DIR + "/ui-dropdown-" + name + ".png")
        })
    }
    function openDialog(component, properties) {
        if (modal) modal.destroy()
        modal = component.createObject(root.contentItem, properties)
        check(modal, "Dialog creation failed: " + component.errorString())
        modal.closed.connect(function(result) { root.lastResult = result })
        modal.open()
    }
    Component.onCompleted: {
        Global.animationSpeed = 1
        Global.settingsPath = SMOKE_DIR + "/settings.json"
        BuildKits.refresh()
        Colors.applyColorScheme("midnight")
        Colors.setThemeColor("#2f8cff")
        Global.mainWindow_popupBackdrop = frame
        timer.start()
    }
    Timer {
        id: timer
        interval: 350; repeat: true
        onTriggered: {
            if (root.capturing || root.advancing) return
            root.advancing = true
            try {
                switch (root.step++) {
                case 0:
                    root.checkDialogFades()
                    root.check(plain.currentIndex === 0, "Initial business value was not selected: index=" + plain.currentIndex + " count=" + plain.count + " value=" + plain.value + " lookup=" + plain.indexOfValue(plain.value))
                    UiInput.click(plain)
                    root.check(plain.popup.visible && !plain.popup.modal && !plain.popup.dim, "Dropdown must open without a dimming modal")
                    root.check(plain.popup.background.backdropSource === frame && plain.popup.background.color.a < 0.95,
                               "Dropdown must use a translucent surface and an external backdrop")
                    console.log("DROPDOWN_BACKDROP_BLUR_ENABLED: " + plain.popup.background.blurEnabled)
                    UiInput.key(plain, Qt.Key_Down)
                    root.check(root.plainValue === "first", "Highlighting committed a value prematurely")
                    break
                case 1:
                    UiInput.key(plain, Qt.Key_Return)
                    UiInput.settle()
                    root.check(root.plainValue === "second" && !plain.popup.visible && plain.activeFocus, "Enter did not commit and restore focus: value=" + root.plainValue + " visible=" + plain.popup.visible + " focus=" + plain.activeFocus)
                    UiInput.click(plain); UiInput.key(plain, Qt.Key_Down); UiInput.key(plain, Qt.Key_Escape)
                    UiInput.settle()
                    root.check(root.plainValue === "second" && !plain.popup.visible, "Escape committed a pending value")
                    plain.options = [root.simpleOptions[2], root.simpleOptions[0], root.simpleOptions[1]]
                    UiInput.settle()
                    root.check(plain.currentIndex === 2 && plain.currentLabel === "第二项" && root.plainValue === "second", "Reordering options changed the business value: index=" + plain.currentIndex + " label=" + plain.currentLabel)
                    break
                case 2:
                    UiInput.click(before); UiInput.key(before, Qt.Key_Tab)
                    root.check(plain.activeFocus, "Tab did not enter the selector")
                    UiInput.key(plain, Qt.Key_Space)
                    root.check(plain.popup.visible, "Space did not open the selector")
                    UiInput.click(before)
                    UiInput.settle()
                    root.check(!plain.popup.visible && before.activeFocus, "Outside click did not close and focus its target")
                    UiInput.click(root.find(shops, "newShopContainerChoice"))
                    break
                case 3:
                    var combo = root.find(shops, "newShopContainerChoice")
                    root.check(combo.popup.visible && root.contextRequests === 0, "Container selector still uses the global context menu")
                    var list = combo.popup.contentItem
                    UiInput.click(list.itemAtIndex(0), 20, 10)
                    root.check(combo.popup.visible, "Clicking a group header selected a container")
                    list.positionViewAtIndex(6, ListView.Center); list.forceLayout()
                    break
                case 4:
                    var combo = root.find(shops, "newShopContainerChoice")
                    var entry = combo.popup.contentItem.itemAtIndex(6)
                    root.check(entry && entry.modelData.swatch, "Shulker options lack color swatches")
                    root.insideWindow(combo)
                    root.screenshot("containers-dark", function() { UiInput.click(entry, 60, entry.headingHeight + 15) })
                    break
                case 5:
                    root.check(root.find(shops, "newShopContainerChoice").value === "orange_shulker_box", "Mouse selection did not commit the container ID")
                    Colors.applyColorScheme("cloud")
                    var templates = BuildKits.options(0)
                    root.check(templates.length > 0, "No template fixture")
                    root.openDialog(projectDialog, {projectData: {name: "dropdown", namespace: "dropdown", templateId: templates[0].value,
                        version: templates[0].versions[0], dataVersion: 0, generatePath: SMOKE_DIR}, templateOptions: templates})
                    break
                case 6:
                    var combo = root.find(root.modal, "projectTemplateChoice")
                    UiInput.click(combo)
                    root.check(combo.popup.visible, "Selector inside project dialog failed to open")
                    root.check(combo.popup.background.backdropSource === root.find(root.modal, "popupPanel"),
                               "Dropdown inside a modal must sample the modal panel")
                    root.screenshot("project-light")
                    break
                case 7:
                    root.width = 720; root.height = 540
                    break
                case 8:
                    var combo = root.find(root.modal, "projectTemplateChoice")
                    root.insideWindow(combo)
                    UiInput.key(combo, Qt.Key_Escape)
                    UiInput.settle()
                    root.check(root.modal.opened && !combo.popup.visible, "Escape closed the containing dialog")
                    root.modal.close(null)
                    break
                case 9:
                    root.openDialog(shopDialog, {shop: {registrationName: "smoke", containerType: "barrel"}, containerOptions: Constants.shopContainerOptions})
                    break
                case 10:
                    var combo = root.find(root.modal, "shopContainerChoice")
                    UiInput.click(combo); UiInput.key(combo, Qt.Key_End)
                    root.screenshot("shop-light-compact", function() {
                        root.check(combo.highlightedIndex === combo.count - 1, "Opening the list reset a pending keyboard selection")
                        UiInput.key(combo, Qt.Key_Return); root.modal.submit()
                    })
                    break
                case 11:
                    root.check(root.modal.result && root.modal.result.containerType === "hopper_minecart",
                               "Shop settings did not commit the business value: " + root.modal.validationMessage)
                    if (root.modal.opened) { --root.step; return }
                    root.check(root.lastResult && root.lastResult.containerType === "hopper_minecart", "Shop settings saved the wrong container ID: " + JSON.stringify(root.lastResult))
                    root.modal.destroy(); root.modal = null
                    root.width = 1100; root.height = 760
                    break
                case 12:
                    UiInput.click(edge)
                    root.check(edge.popup.visible && edge.popup.y < 0, "Bottom-edge selector did not open upward")
                    root.insideWindow(edge)
                    root.screenshot("edge-light", function() { UiInput.key(edge, Qt.Key_Escape) })
                    break
                case 13:
                    UiInput.click(moving)
                    root.previousPopupY = moving.popup.contentItem.mapToItem(null, 0, 0).y
                    scroller.contentY = 60
                    break
                case 14:
                    root.check(Math.abs(moving.popup.contentItem.mapToItem(null, 0, 0).y - root.previousPopupY + 60) < 2, "Popup did not follow its scrolled anchor")
                    UiInput.key(moving, Qt.Key_Escape)
                    root.plainValue = "missing-id"
                    root.check(plain.currentIndex === -1 && plain.currentLabel.indexOf("missing-id") >= 0, "Invalid saved value was hidden or overwritten")
                    plain.options = []; root.plainValue = ""
                    root.check(!plain.enabled && plain.currentLabel === plain.emptyText, "Empty model is not a disabled empty state")
                    root.check(root.contextRequests === 0, "Dropdown requested a global context menu")
                    menu.openAt(330, 280)
                    menu.openSubmenu(0, root.find(menu, "menuViewport"))
                    break
                case 15:
                    root.check(root.find(menu, "contextMenuSurface").backdropSource === frame
                               && root.find(menu, "contextSubmenuSurface").visible,
                               "Context menus must share the frosted backdrop")
                    root.screenshot("menu-light")
                    break
                case 16:
                    menu.close()
                    UiInput.settle(600)
                    frame.visible = false
                    flatBackdrop.visible = true
                    flatBackdrop.color = "#404040"
                    Global.mainWindow_popupBackdrop = flatBackdrop
                    menu.menuItems = explorer.contextMenuItems(["/sample.xcseItem"])
                    menu.openAt(100, 70)
                    break
                case 17:
                    UiInput.settle(250)
                    root.checkMenuLabels(root.find(menu, "menuViewport"))
                    root.screenshot("file-menu-shape", root.checkMenuExterior)
                    break
                case 18:
                    menu.menuItems = explorer.directoryContextMenuItems("/sample")
                    menu.openAt(100, 70)
                    break
                case 19:
                    UiInput.settle(250)
                    root.checkMenuLabels(root.find(menu, "menuViewport"))
                    root.screenshot("directory-menu-shape", root.checkMenuExterior)
                    break
                case 20:
                    menu.close()
                    console.log("DROPDOWN_UI_SMOKE_PASSED: mouse, keyboard, focus, stable values, grouped headers/colors, dialogs, resize, upward placement, scroll anchoring, empty states, frosted surfaces, file/folder menu labels and rounded shadows")
                    Qt.exit(0)
                }
            } catch (error) { console.error("DROPDOWN_UI_SMOKE_FAILED step " + root.step + ": " + error); Qt.exit(1) }
            finally { root.advancing = false }
        }
    }
}
