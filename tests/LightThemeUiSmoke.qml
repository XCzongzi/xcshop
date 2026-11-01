pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import xcshop
import "qrc:/qt/qml/xcshop/js/WorkspaceSchema.js" as Schema

Window {
    id: root
    visible: true
    x: GraphicsInfo.api === GraphicsInfo.Software ? -10000 : 0
    y: GraphicsInfo.api === GraphicsInfo.Software ? -10000 : 0
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint | Qt.WindowDoesNotAcceptFocus
    width: 1280; height: 900
    color: Colors.background_n
    property var themes: ["cloud", "glacier", "lavender", "mint", "parchment", "blush"]
    property int themeIndex: 0
    property int step: 0
    property int sceneIndex: 0
    property int screenshots: 0
    property bool pending: false
    property var page: null
    property string project: SMOKE_DIR + "/theme-project"
    readonly property string captureDirectory: SMOKE_OUTPUT_DIR + "/theme-qa/"
            + (GraphicsInfo.api === GraphicsInfo.Software ? "software" : "gpu")
    readonly property var scenes: [
        {name: "item", component: itemPage, kind: "Item"},
        {name: "ui", component: uiPage, kind: "UI"},
        {name: "cost", component: costPage, kind: "Cost"},
        {name: "display", component: displayPage, kind: "Display"},
        {name: "dashboard", component: dashboardPage, kind: "Global"},
        {name: "settings", component: settingsPage},
        {name: "start", component: startPage},
        {name: "creating", component: creatingPage},
        {name: "about", component: aboutPage},
        {name: "item-image", component: itemPage, kind: "Item", mode: "image"},
        {name: "settings-image", component: settingsPage, mode: "image"},
        {name: "item-compact", component: itemPage, kind: "Item", width: 680, height: 760},
        {name: "settings-compact", component: settingsPage, width: 680, height: 760}
    ]
    XCFile { id: file }
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Colors.background_n
        Item {
            id: backdrop
            anchors.fill: parent
            Image {
                anchors.fill: parent
                source: "qrc:/assets/backgrounds/望夜城.png"
                fillMode: Image.PreserveAspectCrop
                visible: Global.backgroundMode === "image"
                layer.enabled: Global.backgroundBlur > 0 && GraphicsInfo.api !== GraphicsInfo.Software
                layer.effect: MultiEffect { blurEnabled: true; blur: Global.backgroundBlur }
            }
            AmbientBackground { anchors.fill: parent }
        }
        // Keep asynchronous GPU readbacks active on the offscreen platform.
        NumberAnimation on opacity { from: 0.999; to: 1; duration: 500; loops: Animation.Infinite }
    }
    Component { id: itemPage; PageOnItem {} }
    Component { id: uiPage; PageOnUI {} }
    Component { id: costPage; PageOnCost {} }
    Component { id: displayPage; PageOnDisplay {} }
    Component { id: dashboardPage; PageOnTotal {} }
    Component { id: settingsPage; PageOnSettings { fullScreen: false } }
    Component { id: startPage; PageOnStart { fullScreen: false; mainWindow: root } }
    Component { id: creatingPage; PageOnCreating { fullScreen: false } }
    Component { id: aboutPage; PageOnAbout {} }
    Component { id: dialogPage; PopupTextInput { title: "浅色主题 · 输入确认"; content: "为新的商品输入名称。" } }
    Component {
        id: gallery
        Item {
            Rectangle {
                width: 264; height: parent.height
                color: Colors.panel
                Column {
                    x: 20; y: 26; spacing: 16
                    XCText { xcText: "主题 · " + Colors.colorScheme; onCenter: false; xcFontSize: 22 }
                    XCText { xcText: "侧栏 / 路径 / 已打开文件"; onCenter: false; textColor: Colors.banned; xcFontSize: 12 }
                    FileButton { objectName: "openedFile"; width: 224; height: 34; opened: true; text: "已打开的商品.xcseItem"; icon: "Item" }
                    IconButton { text: "设置"; icon: "qrc:/assets/gui/controls/settings.png" }
                    Row {
                        spacing: 8
                        ImageButton { objectName: "monoIcon"; imageSource: "qrc:/assets/gui/titleBar/close.png"; btnSize: 32; imgSize: 24 }
                        ImageButton { imageSource: "qrc:/assets/gui/controls/expand_up.png"; btnSize: 32; imgSize: 24 }
                    }
                }
            }
            ContentSurface {
                objectName: "sampleCard"
                x: 284; y: 20; width: parent.width - 304; height: parent.height - 40
                Column {
                    x: 24; y: 24; width: parent.width - 48; spacing: 16
                    XCText { xcText: "控件与交互状态"; onCenter: false; xcFontSize: 24 }
                    XCText { xcText: "辅助说明需要清晰可读；主题差异来自背景、表面与强调色。"; onCenter: false; textColor: Colors.banned; xcFontSize: 12; boldFont: false }
                    Row {
                        spacing: 12
                        ActionButton { objectName: "primaryAction"; text: "保存更改"; primary: true }
                        ActionButton { text: "次要操作" }
                        ActionButton { text: "危险操作"; destructive: true }
                        ActionButton { text: "不可用"; enabled: false }
                        ActionButton { text: "悬停"; hovered: true }
                        ActionButton { text: "按下"; pressed: true }
                    }
                    XCTextField { objectName: "placeholderField"; width: parent.width; placeholderText: "输入框提示 · {{宏}}" }
                    XCTextField {
                        objectName: "selectionField"; width: parent.width; text: "可选择的文字"
                        Component.onCompleted: { forceActiveFocus(); selectAll() }
                    }
                    VariableTextField {
                        objectName: "syntaxField"
                        width: parent.width; height: 96; syntaxHighlightMode: 2
                        Component.onCompleted: setContent('minecraft:stone[minecraft:custom_name="测试",minecraft:max_stack_size=16] 2')
                    }
                    Row {
                        spacing: 20
                        XCCheckBox { objectName: "checkedBox"; text: "已选中"; checked: true }
                        XCCheckBox { text: "未选中" }
                        XCCheckBox { text: "不可用"; enabled: false }
                        BooleanSwitch { objectName: "styleSwitch"; label: "B"; checked: true }
                    }
                    RadioGroup { text: "触发方式"; options: ["取得商品", "掷出商品"]; initialOption: 0 }
                    XCComboBox {
                        id: sampleCombo
                        objectName: "sampleCombo"
                        width: 300; value: "one"
                        options: [{value: "one", label: "第一项"}, {value: "two", label: "第二项"}, {value: "three", label: "第三项"}]
                        onValueActivated: function(value) { sampleCombo.value = value }
                    }
                    ElementSelectionCompact { width: parent.width; selectionId: "Item" }
                    XCTextArea { width: parent.width; height: 68; placeholderText: "多行文本提示" }
                    Row {
                        spacing: 24
                        XCText { xcText: "可点击的链接"; onCenter: false; xcFontSize: 13; textColor: Colors.accentText; underlineFont: true }
                        XCText { xcText: "错误提示"; onCenter: false; xcFontSize: 13; textColor: Colors.error }
                        XCText { xcText: "警告提示"; onCenter: false; xcFontSize: 13; textColor: Colors.warning }
                    }
                    XCSlider { width: 350; value: 0.6 }
                }
            }
        }
    }

    function check(ok, message) { if (!ok) throw new Error(Colors.colorScheme + ": " + message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) {
            var result = find(child, name)
            if (result) return result
        }
        return null
    }
    function over(top, bottom) {
        return Qt.rgba(top.r * top.a + bottom.r * (1 - top.a),
                       top.g * top.a + bottom.g * (1 - top.a),
                       top.b * top.a + bottom.b * (1 - top.a), 1)
    }
    function luminance(color) {
        function channel(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return channel(color.r) * 0.2126 + channel(color.g) * 0.7152 + channel(color.b) * 0.0722
    }
    function contrast(a, b) {
        var x = luminance(a), y = luminance(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }
    function readable(ink, background, label) {
        var score = contrast(over(ink, background), background)
        check(score >= 4.5, label + " contrast " + score.toFixed(2) + " < 4.5")
    }
    function validatePalette() {
        var canvas = Colors.background_n
        var card = over(Colors.changeA(Colors.card, 0.38), canvas)
        var field = over(Colors.changeA(Colors.input, 0.36), card)
        var focused = over(Colors.changeA(Colors.input, 0.72), card)
        var panel = over(Colors.panel, canvas)
        for (var surface of [canvas, card, field, focused, panel]) {
            readable(Colors.text, surface, "primary text")
            readable(Colors.banned, surface, "secondary text")
        }
        readable(Colors.changeA(Colors.placeholder, 0.78), field, "placeholder")
        readable(Colors.changeA(Colors.placeholder, 0.78), focused, "focused placeholder")
        readable(Colors.text, over(Colors.selection, field), "selected input text")
        readable(Colors.text, over(Colors.selectedRow, panel), "opened file")
        readable(Colors.error, card, "error")
        readable(Colors.warning, card, "warning")
        var original = Colors.themeColor.toString()
        for (var accent of Colors.accentChoices.concat(["#000000", "#ffffff"])) {
            Colors.setThemeColor(accent)
            readable(Colors.accentContent, Colors.accentFill, "primary action")
            readable(Colors.accentContent, over(Qt.rgba(1, 1, 1, 0.14), Colors.accentFill), "hovered action")
            readable(Colors.selectionContent, over(Colors.changeA(Colors.border, 0.66), card), "style toggle " + accent + " ink=" + Colors.selectionContent)
            readable(Colors.selectionContent, over(Colors.changeA(Colors.border, 0.90), card), "checkbox " + accent + " ink=" + Colors.selectionContent)
            check(Qt.colorEqual(Colors.accentText, accent) && Qt.colorEqual(Colors.accentFill, accent),
                  "selected accent changed: " + accent)
        }
        Colors.setThemeColor(original)
        // Colors must not alter the pre-existing material transparency.
        check(Math.abs(Colors.card.a - 224 / 255) < 0.001, "card alpha changed")
        check(Math.abs(Colors.input.a - 232 / 255) < 0.001, "input alpha changed")
        check(Colors.popup.a === 1 && Colors.text.a === 1, "opaque role alpha changed")
    }
    function show(component, properties) {
        if (page) page.destroy()
        page = component.createObject(frame, Object.assign({width: frame.width, height: frame.height}, properties || {}))
        check(page, component.errorString())
        page.width = Qt.binding(function() { return frame.width })
        page.height = Qt.binding(function() { return frame.height })
    }
    function showScene(scene) {
        root.width = scene.width || 1280
        root.height = scene.height || 900
        Global.backgroundMode = scene.mode || "color"
        Global.current_element = scene.kind || "Global"
        Global.set_file([], "sample")
        show(scene.component)
    }
    function capture(name, verify, after) {
        check(Math.abs(page.width - frame.width) < 1 && Math.abs(page.height - frame.height) < 1,
              "test scene did not follow the resized viewport")
        pending = true
        var path = captureDirectory + "/" + themes[themeIndex] + "-" + name + ".png"
        frame.grabToImage(function(result) {
            try {
                check(result.saveToFile(path), "could not save " + path)
                ++root.screenshots
                if (verify) verify(path)
                if (after) after()
                root.pending = false
            } catch (error) { root.fail(error) }
        }, Qt.size(frame.width, frame.height))
    }
    function verifyGallery(path) {
        var card = find(page, "sampleCard")
        var point = card.mapToItem(frame, 16, 16)
        var background = sample(path, point)
        check(background.a > 0, "screenshot sampling failed")
        readable(Colors.banned, background, "rendered secondary text (" + Global.backgroundMode + ")")
        var field = find(page, "placeholderField")
        point = field.mapToItem(frame, 4, field.height / 2)
        background = sample(path, point)
        readable(field.placeholderTextColor, background, "rendered placeholder (" + Global.backgroundMode + ")")
        var syntax = find(page, "syntaxField")
        point = syntax.input.mapToItem(frame, 4, 20)
        background = sample(path, point)
        for (var key of ["itemIdColor", "keyColor", "stringColor", "numberColor", "quantityColor", "punctuationColor", "booleanColor", "invalidColor"])
            readable(Qt.color(syntax[key]), background, "rendered syntax " + key + " (" + Global.backgroundMode + ")")
        var icon = find(page, "monoIcon")
        point = icon.mapToItem(frame, icon.width / 2, icon.height / 2)
        var pixel = sample(path, point)
        check(luminance(pixel) < 0.25, "white close icon was not recolored")
    }
    function sample(path, point) {
        // grabToImage stores physical pixels, including Windows display scaling.
        return UiInput.imageColor(path, Math.round(point.x * Screen.devicePixelRatio),
                                 Math.round(point.y * Screen.devicePixelRatio))
    }
    function fail(error) { console.error("LIGHT_THEME_UI_SMOKE_FAILED theme=" + themeIndex + " step=" + step + ": " + error); Qt.exit(1) }
    Component.onCompleted: {
        Global.animationSpeed = 20
        Global.settingsPath = SMOKE_DIR + "/settings.json"
        Global.project_location = project
        Global.version = "26.3"
        Global.mainWindow_backdrop = backdrop
        Global.mainWindow_popupBackdrop = backdrop
        file.folder(project)
        file.folder(captureDirectory)
        file.writeAtomic(project + "/xcshop.json", JSON.stringify({name: "浅色视觉测试", namespace: "theme_test", version: "26.3", shops: [], generatePath: SMOKE_DIR}))
        var item = Schema.item()
        item.item = "minecraft:stone 2"
        item.operations = [Schema.operation("购买商品")]
        item.operations[0].trigger.execute = {kind: "command", value: "say {{player}}"}
        file.writeAtomic(project + "/Item/sample.xcseItem", JSON.stringify(item))
        file.writeAtomic(project + "/Display/sample.xcseDisplay", JSON.stringify(Schema.display()))
        file.writeAtomic(project + "/Cost/sample.xcseCost", JSON.stringify({display: "等级", type: {kind: "experience_level", value: "5", filter: false}}))
        file.writeAtomic(project + "/UI/sample.xcseUI", JSON.stringify({containerType: "generic_9x3", customName: "商店预览", slots: [], nestedGroups: []}))
        timer.start()
    }
    Timer {
        id: timer
        interval: 240; repeat: true
        onTriggered: {
            if (root.pending) return
            try {
                switch (root.step++) {
                case 0:
                    root.width = 1280; root.height = 900
                    Global.backgroundMode = "color"
                    Colors.applyColorScheme(root.themes[root.themeIndex])
                    Colors.setThemeColor(Colors.accentForColorScheme(Colors.colorScheme) || "#2f8cff")
                    root.validatePalette()
                    Global.backgroundMode = "color"
                    root.show(gallery)
                    break
                case 1:
                    root.capture("controls-solid", root.verifyGallery)
                    break
                case 2:
                    Global.backgroundMode = "image"
                    break
                case 3:
                    root.capture("controls-image", root.verifyGallery)
                    break
                case 4:
                    Global.backgroundMode = "color"
                    UiInput.click(root.find(root.page, "sampleCombo"))
                    break
                case 5:
                    root.check(root.find(root.page, "sampleCombo").popup.visible, "dropdown did not open")
                    root.capture("dropdown", null, function() {
                        UiInput.key(root.find(root.page, "sampleCombo"), Qt.Key_Escape)
                        root.show(dialogPage)
                        root.page.open()
                    })
                    break
                case 6:
                    root.capture("dialog", null, function() {
                        root.sceneIndex = 0
                        root.showScene(root.scenes[0])
                    })
                    break
                case 7:
                    var scene = root.scenes[root.sceneIndex]
                    if (root.page.dataLoaded !== undefined) root.check(root.page.dataLoaded, root.page.dataError)
                    root.capture(scene.name, null, function() {
                        if (++root.sceneIndex < root.scenes.length) {
                            var next = root.scenes[root.sceneIndex]
                            root.showScene(next)
                            root.step = 7
                        } else if (++root.themeIndex < root.themes.length) {
                            root.step = 0
                        } else {
                            for (var darkTheme of ["midnight", "slate", "violet", "forest", "amber", "rose"]) {
                                Colors.applyColorScheme(darkTheme)
                                root.check(!Colors.isLight && Qt.colorEqual(Colors.card, Colors.foreground)
                                           && Qt.colorEqual(Colors.input, Colors.background)
                                           && Qt.colorEqual(Colors.accentText, Colors.border)
                                           && Qt.colorEqual(Colors.control, Colors.pressed)
                                           && Qt.colorEqual(Colors.popup, Colors.background_n)
                                           && Qt.colorEqual(Colors.outline, Colors.text)
                                           && Qt.colorEqual(Colors.selectedRow, Colors.banned), "dark role fallback changed")
                            }
                            console.log("LIGHT_THEME_UI_SMOKE_PASSED: 6 themes, 7 accents, composited contrast, solid/image backgrounds, icons, selections, dropdowns, dialogs, 9 pages and compact views; screenshots=" + root.screenshots)
                            Qt.exit(0)
                        }
                    })
                    break
                }
            } catch (error) { root.fail(error) }
        }
    }
}
