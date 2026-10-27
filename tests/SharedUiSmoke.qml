pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    width: 1280
    height: 900
    color: Colors.background_n
    property var page: null
    property int step: 0
    property var lastResult: null
    property int closedCount: 0
    property bool capturePending: false
    property string project: SMOKE_DIR + "/shared-ui"
    XCFile {
        id: file
    }
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Colors.background_n
        NumberAnimation on opacity {
            from: 0.999
            to: 1
            duration: 500
            loops: Animation.Infinite
        }
    }
    Component {
        id: controls
        Column {
            spacing: 12
            ActionButton {
                objectName: "primaryAction"
                text: "主操作"
                primary: true
            }
            VariableTextField {
                objectName: "field"
                width: 500
                height: 128
            }
            VariableTextArea {
                objectName: "area"
                width: 500
                height: 128
            }
            ComboBox {
                objectName: "choice"
                options: ["甲", "乙", "丙"]
            }
            ElementSelection {
                objectName: "fullSelection"
                selectionId: "ui"
            }
            ElementSelectionCompact {
                objectName: "compactSelection"
                selectionId: "ui"
            }
        }
    }
    Component {
        id: interfacePage
        SettingsInterface {}
    }
    Component {
        id: notice
        PopupNotice {}
    }
    Component {
        id: textInput
        PopupTextInput {}
    }
    Component {
        id: jsonEditor
        PopupJsonTextEditor {}
    }
    Component {
        id: shopSettings
        PopupShopSettings {}
    }
    Component {
        id: uiPage
        PageOnUI {}
    }

    function check(value, message) {
        if (!value)
            throw new Error(message)
    }
    function findWhere(item, predicate) {
        if (predicate(item))
            return item
        for (var child of item.children || []) {
            var found = findWhere(child, predicate)
            if (found)
                return found
        }
        return null
    }
    function find(name) {
        return findWhere(page, function (item) {
            return item.objectName === name
        })
    }
    function show(component, properties) {
        if (page)
            page.destroy()
        page = component.createObject(frame, Object.assign({
            width: frame.width,
            height: frame.height
        }, properties || {}))
        check(page, "Creation failed: " + component.errorString())
        page.width = Qt.binding(function () {
            return frame.width
        })
        page.height = Qt.binding(function () {
            return frame.height
        })
    }
    function openPopup(component, properties) {
        show(component, properties)
        page.closed.connect(function (result) {
            root.lastResult = result;
            ++root.closedCount
        })
        // Shader shadows are not available in Qt's software renderer.
        find("popupPanel").layer.enabled = false
        page.open()
    }
    function screenshot(name, afterCapture) {
        capturePending = true
        frame.grabToImage(function (result) {
            result.saveToFile(SMOKE_OUTPUT_DIR + "/ui-shared-" + name + ".png")
            root.capturePending = false
            if (afterCapture)
                afterCapture()
        })
    }
    Component.onCompleted: {
        Global.animationSpeed = 20
        Global.settingsPath = SMOKE_DIR + "/settings.json"
        Global.project_location = project
        file.writeAtomic(project + "/UI/source.xcseUI", JSON.stringify({
            containerType: "generic_9x3",
            slots: [],
            nestedGroups: [
                {
                    id: "group",
                    name: "测试组",
                    slots: [0],
                    layoutInput: {
                        enabled: true,
                        id: "input",
                        defaultValue: "0",
                        result: {
                            scoreboard: "test",
                            target: "@s"
                        },
                        connections: [
                            {
                                element: "UI/one.xcseUI",
                                value: "1"
                            },
                            {
                                element: "UI/two.xcseUI",
                                value: "2"
                            },
                            {
                                element: "UI/three.xcseUI",
                                value: "3"
                            }
                        ]
                    }
                }
            ]
        }))
        timer.start()
    }
    Timer {
        id: timer
        interval: 300
        repeat: true
        onTriggered: {
            if (root.capturePending)
                return
            try {
                switch (root.step++) {
                case 0:
                    root.check(Colors.colorSchemes.length === 12, "Theme catalog lost palettes")
                    for (var choice of Colors.colorSchemes) {
                        Colors.applyColorScheme(choice.id)
                        root.check(Qt.colorEqual(Colors.background_n, choice.background), "Theme preview differs from applied palette")
                    }
                    Colors.applyColorScheme("midnight")
                    root.show(controls)
                    Colors.setThemeColor("black")
                    root.check(Qt.colorEqual(root.find("primaryAction").textColor, "white"), "Dark accent needs light action text")
                    Colors.setThemeColor("white")
                    root.check(Qt.colorEqual(root.find("primaryAction").textColor, "black"), "Light accent needs dark action text")
                    Colors.setThemeColor("#2f8cff")
                    break
                case 1:
                    for (var name of ["field", "area"]) {
                        var editor = root.find(name)
                        editor.setContent("首行\n{{宏}}")
                        root.check(editor.getContent() === "首行\n{{宏}}", "Editor content was not synchronized")
                        editor.input.text = "修改后"
                        editor.commit()
                        root.check(editor.content === "修改后", "Editor failed to commit")
                    }
                    var selector = root.find("choice")
                    selector.selected = 2
                    root.check(selector.currentLabel === "丙", "Programmatic index selection lost")
                    selector.menuOptions[1].action()
                    root.check(selector.selected === 1 && selector.currentLabel === "乙", "Menu selection did not update legacy index")
                    var full = root.find("fullSelection"), compact = root.find("compactSelection")
                    full.requestElementSelection()
                    compact.requestElementSelection()
                    root.check(!full.waitingForSelection && compact.waitingForSelection, "Selection focus was not exclusive")
                    SignalBus.elementSelectionResolved("UI/source.xcseUI")
                    root.check(compact.hasSelection && !compact.waitingForSelection && !full.hasSelection, "Selection resolution reached the wrong view")
                    compact.setElement("Item/wrong.xcseItem", true)
                    root.check(compact.validationMessage.length > 0, "Wrong element type was accepted")
                    compact.clearElement(false)
                    root.check(!compact.hasSelection, "Selection clear failed")
                    root.show(interfacePage)
                    break
                case 2:
                    for (var palette of Colors.colorSchemes) {
                        var surface = root.find("themePreviewSurface_" + palette.id)
                        root.check(surface && Qt.colorEqual(surface.color, palette.background), "Theme preview is blank or has the wrong background")
                    }
                    root.screenshot("settings-dark", function () {
                        Colors.applyColorScheme("cloud")
                        root.width = 680
                        root.height = 520
                    })
                    break
                case 3:
                    var section = root.findWhere(root.page, function (item) {
                        return item.title === "界面" && item.availableWidth !== undefined
                    })
                    root.check(section && section.contentHeight > section.availableHeight, "Compact settings cannot scroll")
                    root.screenshot("settings-light-compact", function () {
                        root.width = 1280
                        root.height = 900
                        root.openPopup(notice, {
                            content: "提示内容",
                            doubleButton: true
                        })
                    })
                    break
                case 4:
                    root.check(root.find("popupPanel").width === 520, "Notice shell geometry changed")
                    var panel = root.find("popupPanel")
                    root.check(panel.topLeftRadius === 0 && panel.topRightRadius === 0
                               && panel.bottomLeftRadius === 15 && panel.bottomRightRadius === 15,
                               "Popup must have square top corners and rounded bottom corners")
                    root.page.close(1)
                    break
                case 5:
                    root.check(root.closedCount === 1 && root.lastResult === 1, "Notice result/lifecycle changed")
                    root.openPopup(textInput, {
                        value: "初始值"
                    })
                    break
                case 6:
                    var input = root.findWhere(root.page, function (item) {
                        return item.text === "初始值" && typeof item.selectAll === "function"
                    })
                    root.check(input && input.activeFocus, "Text popup did not focus its input")
                    input.text = "新值"
                    input.accepted()
                    break
                case 7:
                    root.check(root.closedCount === 2 && root.lastResult === "新值", "Text popup return value changed")
                    root.openPopup(jsonEditor, {
                        jsonText: '[{"text":"你好","color":"gold","bold":true}]'
                    })
                    break
                case 8:
                    root.check(root.page.exportedJson().indexOf('"gold"') >= 0, "JSON editor lost text style")
                    root.screenshot("json-light", function () {
                        root.page.close({
                            jsonText: root.page.exportedJson()
                        })
                    })
                    break
                case 9:
                    root.check(root.lastResult.jsonText.indexOf("你好") >= 0, "JSON result was not preserved")
                    root.openPopup(shopSettings, {
                        shop: {
                            registrationName: "test",
                            containerType: "barrel"
                        },
                        containerOptions: Constants.shopContainerOptions
                    })
                    break
                case 10:
                    root.page.submit()
                    break
                case 11:
                    root.check(root.lastResult.registrationName === "test" && root.lastResult.containerType === "barrel", "Shop settings result changed")
                    Global.current_element = "UI"
                    Global.set_file([], "source")
                    root.show(uiPage)
                    root.page.selectedNestedGroupId = "group"
                    var tabs = root.findWhere(root.page, function (item) {
                        return item.options && item.options.indexOf && item.options.indexOf("布局输入器") >= 0
                    })
                    root.check(tabs, "UI inspector tabs missing")
                    tabs.selected = 2
                    break
                case 12:
                    root.check(root.find("layoutConnectionRow2"), "Layout input rows were not created")
                    root.findWhere(root.find("layoutConnectionRow0"), function (item) {
                        return item.objectName === "removeCostButton"
                    }).clicked()
                    break
                case 13:
                    var connections = root.page.nestedGroupLayoutInput("group").connections
                    root.check(connections.length === 2 && connections[0].value === "2" && connections[1].value === "3", "Deleting the first row corrupted survivors")
                    var valueField = root.findWhere(root.find("layoutConnectionRow0"), function (item) {
                        return item.objectName === "connectionValueInput"
                    })
                    valueField.text = "22"
                    valueField.editingFinished()
                    root.findWhere(root.find("layoutConnectionRow1"), function (item) {
                        return item.objectName === "removeCostButton"
                    }).clicked()
                    break
                case 14:
                    var connections = root.page.nestedGroupLayoutInput("group").connections
                    root.check(connections.length === 1 && connections[0].value === "22", "Edit after deletion targeted the wrong row")
                    root.findWhere(root.find("layoutConnectionRow0"), function (item) {
                        return item.objectName === "removeCostButton"
                    }).clicked()
                    break
                case 15:
                    root.check(root.page.nestedGroupLayoutInput("group").connections.length === 0, "Deleting the only row failed")
                    root.check(!root.findWhere(root.page, function (item) {
                        return item.connectionDeleting === true
                    }), "Deletion guard was not released")
                    root.page.addNestedGroupLayoutInputConnection("group")
                    root.page.addNestedGroupLayoutInputConnection("group")
                    break
                case 16:
                    root.findWhere(root.find("layoutConnectionRow0"), function (item) {
                        return item.objectName === "removeCostButton"
                    }).clicked()
                    root.page.selectedNestedGroupId = ""
                    break
                case 17:
                    root.page.selectedNestedGroupId = "group"
                    break
                case 18:
                    root.check(root.page.nestedGroupLayoutInput("group").connections.length === 2, "Interrupted removal deleted a row")
                    root.check(!root.findWhere(root.page, function (item) {
                        return item.connectionDeleting === true
                    }), "Switching groups left input locked")
                    root.findWhere(root.find("layoutConnectionRow0"), function (item) {
                        return item.objectName === "removeCostButton"
                    }).clicked()
                    break
                case 19:
                    root.check(root.page.nestedGroupLayoutInput("group").connections.length === 1, "Removal after switching groups failed")
                    console.log("SHARED_UI_SMOKE_PASSED: themes, actions, editors, choices, selection, settings, popup results/focus, layout row deletion")
                    Qt.exit(0)
                    break
                }
            } catch (error) {
                console.error("SHARED_UI_SMOKE_FAILED step " + root.step + ": " + error)
                Qt.exit(1)
            }
        }
    }
}
