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
    property bool checkingFocus: false
    property string project: SMOKE_DIR + "/shared-ui"
    TextMetrics { id: wrapMetrics }
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
            XCTextField {
                objectName: "singleLineField"
                width: 500
            }
            XCComboBox {
                id: selectionSample
                objectName: "choice"
                options: [{value: "first", label: "甲"}, {value: "second", label: "乙"}, {value: "third", label: "丙"}]
                onValueActivated: function(value) { selectionSample.value = value }
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
    function macroInput(index, valueField) {
        return findWhere(page, function(item) {
            return item.placeholderText === (valueField ? "值" : "参数名")
                    && item.parent.index === index
        })
    }
    function checkLongSelection(editor, syntaxMode) {
        editor.highlightMacros = true
        if (editor.syntaxHighlightMode !== undefined)
            editor.syntaxHighlightMode = syntaxMode
        var input = editor.input || editor
        input.selectByMouse = true
        var body = ("stone {{price}} 中文🙂 long text ").repeat(80)
        var source = syntaxMode === 1 ? "minecraft:stone{display:{Name:'" + body + "'}} 64"
                   : syntaxMode === 2 ? "minecraft:stone[minecraft:custom_name='" + body + "'] 64"
                   : body
        if (editor.setContent)
            editor.setContent(source)
        else
            input.text = source
        input.forceActiveFocus()
        input.cursorPosition = source.length
        UiInput.settle(40)
        var origin = input.positionToRectangle(0)
        if (input.autoScroll !== undefined)
            check(origin.y < input.topPadding || origin.x < input.leftPadding,
                  "Long input did not auto-scroll: " + editor.objectName + "/" + syntaxMode)
        else
            check(input.contentHeight > input.height, "Multiline sample did not overflow")
        var macroPosition = source.indexOf("{{price}}")
        check(Qt.colorEqual(UiInput.textFormatColor(input, macroPosition), Colors.error),
              "Macro colour is missing from the input's actual text layout")
        if (syntaxMode)
            check(Qt.colorEqual(UiInput.textFormatColor(input, 0), editor.itemIdColor),
                  "Syntax colour is missing while editing")
        UiInput.dragSelect(input, input.width - input.rightPadding - 5,
                           input.height - input.bottomPadding - 5,
                           input.leftPadding + 5, input.topPadding + 5)
        check(input.selectedText.length > 0, "Mouse drag failed to select long input: "
              + editor.objectName + "/" + syntaxMode + " cursor=" + input.cursorPosition
              + " origin=" + input.positionToRectangle(0))
        check(Qt.colorEqual(UiInput.textFormatColor(input, macroPosition), Colors.error),
              "Selecting text removed macro colours")
        if (syntaxMode)
            check(Qt.colorEqual(UiInput.textFormatColor(input, 0), editor.itemIdColor),
                  "Selecting text removed syntax colours")
        check(Qt.colorEqual(input.color, Colors.text), "Selection hid unselected text")
        check(input.text === source, "Selection changed input contents")
        input.deselect()
        UiInput.settle(30)
        input.cursorPosition = macroPosition
        UiInput.settle(30)
        var before = input.positionToRectangle(macroPosition)
        var ranges = input.highlightRanges
        input.highlightRanges = []
        input.highlightMacros = false
        UiInput.settle(30)
        var plain = input.positionToRectangle(macroPosition)
        check(Math.abs(before.x - plain.x) < 0.1 && Math.abs(before.y - plain.y) < 0.1,
              "Highlighting moved the text layout or cursor")
        input.highlightRanges = syntaxMode
                ? Qt.binding(function() { return editor.createHighlightRanges(input.text) })
                : ranges
        input.highlightMacros = true
        UiInput.preedit(input, "中")
        UiInput.settle(30)
        check(input.inputMethodComposing && input.text === source,
              "Highlighting changed uncommitted input-method text")
        UiInput.commitText(input, "中")
        UiInput.settle(30)
        check(input.text === source.slice(0, macroPosition) + "中" + source.slice(macroPosition),
              "Input-method commit changed surrounding text")
        check(Qt.colorEqual(UiInput.textFormatColor(input, macroPosition + 1), Colors.error),
              "Macro colour was lost after editing")
        input.undo()
        UiInput.settle(30)
        check(input.text === source, "Highlighting broke undo")
    }
    function checkWrappedLineEnds(editor, syntaxMode, width, fontSize) {
        editor.width = width
        editor.height = 320
        if (editor.syntaxHighlightMode !== undefined)
            editor.syntaxHighlightMode = syntaxMode
        var input = editor.input
        input.editorFontSize = fontSize
        input.selectByMouse = true
        var source = 'command_block[custom_name={"text":"执行函数实例","color":"white","italic":false},lore=[{"text":"调用菜单刷新函数","color":"gray","italic":false}]] 1'
        editor.setContent(source)
        input.forceActiveFocus()
        input.cursorPosition = 0
        UiInput.settle(150)
        var rows = []
        for (var i = 0; i + 1 < source.length; ++i) {
            var before = input.positionToRectangle(i)
            var after = input.positionToRectangle(i + 1)
            if (before.y === after.y)
                continue
            // TextInput's positionToRectangle omits padding; TextEdit includes it.
            if (input.autoScroll !== undefined) {
                before.x += input.leftPadding
                before.y += input.topPadding
            }
            wrapMetrics.font = input.font
            wrapMetrics.text = source.charAt(i)
            var right = before.x + wrapMetrics.advanceWidth
            root.check(input.width - input.rightPadding - right < fontSize * 1.5,
                       "Soft wrapping left a large unused gap: " + editor.objectName + "/" + width)
            rows.push({start: i, end: i + 1, x: before.x, y: before.y + before.height / 2})
        }
        root.check(rows.length > 0, "Boundary sample did not wrap")
        for (var row of rows) {
            var rightEdge = input.width - 1
            UiInput.click(input, rightEdge, row.y)
            UiInput.settle(20)
            root.check(input.cursorPosition === row.end,
                       "Clicking beyond a soft line end missed its last character: " + editor.objectName)
            UiInput.dragSelect(input, row.x + 0.5, row.y, rightEdge, row.y)
            UiInput.settle(20)
            root.check(input.selectedText === source.slice(row.start, row.end),
                       "Mouse drag could not select just the final character: " + editor.objectName)
            UiInput.key(input, Qt.Key_Backspace)
            UiInput.settle(20)
            root.check(input.text === source.slice(0, row.start) + source.slice(row.end),
                       "Editing the final character changed a neighbouring character")
            input.undo()
            UiInput.settle(20)
            root.check(input.text === source, "Line-end editing broke undo")
            input.deselect()
        }
    }
    function checkMacroFocus() {
        var firstName = macroInput(0, false), firstValue = macroInput(0, true)
        var secondName = macroInput(1, false)
        check(firstName && firstValue && secondName, "Macro inputs were not created")
        UiInput.click(firstName)
        check(firstName.activeFocus, "Macro name did not focus on its first click")
        UiInput.click(firstValue)
        UiInput.settle(35)
        check(firstValue === macroInput(0, true) && firstValue.activeFocus,
              "Switching macro fields rebuilt the clicked input or lost focus")
        UiInput.key(firstValue, Qt.Key_End)
        UiInput.key(firstValue, Qt.Key_9)
        UiInput.click(secondName)
        UiInput.settle(35)
        check(secondName === macroInput(1, false) && secondName.activeFocus,
              "Saving a macro value lost the next row's focus")
        check(page.slotItems(0)[0].macros[0].value === "19", "Macro value was not saved on focus change")
        UiInput.click(firstName)
        UiInput.key(firstName, Qt.Key_End)
        UiInput.key(firstName, Qt.Key_2)
        UiInput.click(firstValue)
        UiInput.settle(35)
        check(firstValue === macroInput(0, true) && firstValue.activeFocus,
              "Saving a macro name lost the next field's focus")
        check(page.slotItems(0)[0].macros[0].name === "price2", "Macro name was not saved")
        UiInput.key(firstValue, Qt.Key_End)
        UiInput.key(firstValue, Qt.Key_8)
        page.notifySlotChanged(0)
        UiInput.settle(35)
        check(firstValue === macroInput(0, true) && firstValue.activeFocus && firstValue.text === "198",
              "An unrelated slot refresh discarded focus or an uncommitted macro edit")
        UiInput.click(secondName)
        UiInput.settle(35)
        var stored = JSON.parse(file.read(project + "/UI/source.xcseUI"))
        check(stored.slots[0].items[0].macros[0].name === "price2"
              && stored.slots[0].items[0].macros[0].value === "198",
              "Macro edits were not persisted")
    }
    function inspectorTabs() {
        return findWhere(page, function(item) {
            return item.options && item.options.indexOf && item.options.indexOf("当前栏位") >= 0
        })
    }
    function checkWorkspaceNavigation() {
        var tabs = inspectorTabs()
        page.selectBasicLayout()
        page.clearCurrentSlot()
        check(tabs.selected === 0, "Empty basic layout kept an unrelated inspector")
        page.setCurrentSlot(-1)
        check(tabs.selected === 0, "Invalid slot changed the inspector")
        page.setCurrentSlot(0)
        check(tabs.selected === 1, "Selecting a slot did not open its editor")
        tabs.selected = 0
        page.setCurrentSlot(0)
        check(tabs.selected === 1, "Reselecting a slot did not return to its editor")
        page.selectNestedGroup("group")
        check(tabs.selected === 2, "Enabled nested input did not open its editor")
        tabs.selected = 0
        page.selectNestedGroup("missing")
        check(tabs.selected === 0 && page.selectedNestedGroupId === "group", "Invalid group changed the context")
        page.selectNestedGroup("other")
        check(tabs.selected === 0, "A disabled input overrode the chosen inspector")
        page.setNestedGroupLayoutInputEnabled("other", true)
        check(tabs.selected === 2, "Enabling the selected input did not open its editor")
        page.setNestingDrawMode(true)
        var slot = findWhere(page, function(item) { return item.isItemSlot === true && item.index === 1 })
        check(slot, "Canvas slot missing")
        UiInput.click(slot)
        check(tabs.selected === 2 && page.currentSlotIndex === 0
              && page.selectedNestedGroup().slots.indexOf(1) >= 0,
              "Drawing a nested slot switched away from the layout editor")
        page.setNestingDrawMode(false)
        UiInput.click(slot)
        check(tabs.selected === 1 && page.currentSlotIndex === 1, "Clicking a canvas slot did not open its editor")
        page.selectBasicLayout()
        page.clearCurrentSlot()
        check(tabs.selected === 0, "Clearing a slot left an empty slot editor")
        page.selectNestedGroup("group")
        UiInput.settle(35)
        var defaultInput = findWhere(page, function(item) { return item.placeholderText === "必填整数" })
        UiInput.click(defaultInput)
        defaultInput.selectAll()
        UiInput.key(defaultInput, Qt.Key_7)
        page.selectNestedGroup("other")
        check(page.nestedGroupLayoutInput("group").defaultValue === "7"
              && page.nestedGroupLayoutInput("other").defaultValue === "0",
              "Changing groups saved an edit into the wrong group: "
              + page.nestedGroupLayoutInput("group").defaultValue + "/"
              + page.nestedGroupLayoutInput("other").defaultValue)
        page.selectNestedGroup("other")
        check(tabs.selected === 0 && page.selectedNestedGroupId === "", "Leaving a group did not restore the inspector")
        page.setCurrentSlot(0)
        UiInput.settle(35)
        var originalMacros = JSON.parse(JSON.stringify(page.slotItems(0)[0].macros))
        var value = macroInput(0, true)
        UiInput.click(value)
        value.selectAll()
        UiInput.key(value, Qt.Key_5)
        page.setCurrentSlot(1)
        check(page.slotItems(0)[0].macros[0].value === "5" && page.slotItems(1).length === 0,
              "Changing slots discarded an edit or saved it into the wrong slot")
        page.updateSaleItemMacros(0, 0, originalMacros)
        page.setCurrentSlot(0)
        page.selectNestedGroup("other")
        page.removeNestedGroup("other")
        check(page.selectedNestedGroupId === "" && tabs.selected === 1,
              "Deleting the selected group left its layout editor open")
        UiInput.settle(35)
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
            slots: [{index: 0, items: [{element: "", filter: {},
                     macros: [{name: "price", value: "1"}, {name: "count", value: "2"}]}]}],
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
                },
                { id: "other", name: "另一个组", slots: [], layoutInput: {enabled: false, defaultValue: "0"} }
            ]
        }))
        timer.start()
    }
    Timer {
        id: timer
        interval: 300
        repeat: true
        onTriggered: {
            if (root.capturePending || root.checkingFocus)
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
                    root.checkingFocus = true
                    root.checkLongSelection(root.find("field"), 1)
                    root.checkLongSelection(root.find("field"), 2)
                    root.checkLongSelection(root.find("area"), 0)
                    root.checkLongSelection(root.find("singleLineField"), 0)
                    root.checkWrappedLineEnds(root.find("field"), 2, 500, 16)
                    root.checkWrappedLineEnds(root.find("field"), 2, 1016, 22)
                    root.checkWrappedLineEnds(root.find("area"), 0, 500, 16)
                    root.checkingFocus = false
                    for (var name of ["field", "area"]) {
                        var editor = root.find(name)
                        editor.setContent("首行\n{{宏}}")
                        root.check(editor.getContent() === "首行\n{{宏}}", "Editor content was not synchronized")
                        editor.input.text = "修改后"
                        editor.commit()
                        root.check(editor.content === "修改后", "Editor failed to commit")
                    }
                    var selector = root.find("choice")
                    selector.value = "third"
                    root.check(selector.currentLabel === "丙", "Programmatic index selection lost")
                    selector.activated(1)
                    root.check(selector.value === "second" && selector.currentLabel === "乙", "Menu selection did not update legacy index")
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
                    root.check(panel.topLeftRadius === 6 && panel.topRightRadius === 6
                               && panel.bottomLeftRadius === 15 && panel.bottomRightRadius === 15,
                               "Popup must have small top corners and larger bottom corners")
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
                    root.page.selectNestedGroup("group")
                    var tabs = root.findWhere(root.page, function (item) {
                        return item.options && item.options.indexOf && item.options.indexOf("布局输入器") >= 0
                    })
                    root.check(tabs, "UI inspector tabs missing")
                    root.check(tabs.selected === 2, "Entering an enabled group did not select the layout inspector")
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
                    root.page.setCurrentSlot(0)
                    var tabs = root.findWhere(root.page, function(item) {
                        return item.options && item.options.indexOf && item.options.indexOf("当前栏位") >= 0
                    })
                    root.check(tabs.selected === 1, "Selecting a slot did not select the slot inspector")
                    break
                case 20:
                    root.checkingFocus = true
                    try {
                        root.checkWorkspaceNavigation()
                        root.checkMacroFocus()
                    } finally { root.checkingFocus = false }
                    console.log("SHARED_UI_SMOKE_PASSED: themes, actions, editors, choices, selection, settings, popup results/focus, layout row deletion, macro focus/persistence, workspace inspector navigation and edit commits")
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
