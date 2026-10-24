import QtQuick
import QtQuick.Window
import xcshop
import "qrc:/qt/qml/xcshop/js/WorkspaceSchema.js" as Schema

Window {
    id: root
    visible: true
    width: 1200; height: 900
    color: Colors.background
    property var page: null
    property int step: 0
    property double phaseStart: 0
    property var activeCard: null
    property var activeInput: null
    property bool observedMotion: false
    property bool observedInsertion: false
    property bool observedResizeFrame: false
    property string project: SMOKE_DIR + "/operations"
    XCFile { id: file }
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Colors.background
        NumberAnimation on opacity { from: 0.999; to: 1; duration: 500; loops: Animation.Infinite }
    }
    Component { id: itemPage; PageOnItem {} }
    Component { id: displayPage; PageOnDisplay {} }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var i = 0; i < item.children.length; ++i) {
            var result = find(item.children[i], name)
            if (result) return result
        }
        return null
    }
    function show(component, kind, name) {
        if (page) page.destroy()
        Global.current_element = kind
        Global.set_file([], name)
        page = component.createObject(frame, {width: frame.width, height: frame.height})
        check(page, "Page creation: " + component.errorString())
        page.width = Qt.binding(function() { return frame.width })
        page.height = Qt.binding(function() { return frame.height })
    }
    function screenshot(name) {
        frame.grabToImage(function(result) { result.saveToFile(APP_DIRPATH + "/ui-operations-" + name + ".png") })
    }
    function checkButtonColors(item) {
        if (item.buttonColor !== undefined && typeof item.setSelected === "function") {
            check(item.enabled, "animation disabled a button")
            check(Qt.colorEqual(item.color, item.buttonColor), "animation changed a button's base color")
        }
        item.children.forEach(checkButtonColors)
    }
    onFrameSwapped: {
        if (!activeCard || !activeInput || !activeInput.resizing)
            return
        try {
            var inputBottom = activeInput.mapToItem(activeCard, Qt.point(0, activeInput.height)).y
            check(activeCard.height + 2 >= inputBottom, "rendered frame lags behind resizable input: frame=" + activeCard.height + " bottom=" + inputBottom + " stage=" + step)
            observedResizeFrame = true
        } catch (error) { console.error("OPERATIONS_UI_SMOKE_FAILED", error); Qt.exit(1) }
    }
    Component.onCompleted: {
        Global.animationSpeed = 20
        Global.project_location = project
        Global.version = "26.3"
        file.folder(project + "/Item"); file.folder(project + "/Display"); file.folder(project + "/Cost")
        check(file.writeAtomic(project + "/Item/example.xcseItem", JSON.stringify(Schema.item())), "item seed")
        check(file.writeAtomic(project + "/Display/example.xcseDisplay", JSON.stringify(Schema.display())), "display seed")
        timer.start()
    }
    Timer {
        id: timer
        interval: 300; repeat: true
        onTriggered: {
            try {
                switch (root.step++) {
                case 0: show(itemPage, "Item", "example"); break
                case 1:
                    check(page.dataLoaded, page.dataError)
                    page.addOperation(false); page.addOperation(false); page.addOperation(false)
                    break
                case 2:
                    var card = find(page, "operationCard0")
                    check(card && card.height > 100, "operation card missing")
                    check(page.eledata.operations.every(function(op) { return op.title === "" }), "operation names have presets")
                    check(find(card,"operationCardHeader").height === 32, "original header strip missing")
                    check(find(card,"operationNumber").xcText === "操作1", "number must be in header control area")
                    var title = find(card, "operationTitle")
                    title.text = "左键购买"; title.editingFinished()
                    find(card, "operationShowInDisplay").checked = false
                    find(card, "operationShowInDisplay").toggled(false)
                    card.addCost(); card.addCost(); card.removeCost(0)
                    var saved = JSON.parse(file.read(project + "/Item/example.xcseItem"))
                    check(saved.operations.length === 3 && saved.operations[0].title === "左键购买", "operation title save")
                    check(saved.operations[0].showInDisplay === false && saved.operations[0].cost.length === 1, "operation cost or visibility save")
                    check(saved.cost === undefined && saved.trigger === undefined, "legacy roots persisted")
                    page.removeOperation(1)
                    screenshot("item-wide")
                    break
                case 3:
                    var firstCard = find(page, "operationCard0")
                    var costTitle = find(firstCard, "operationCostTitle")
                    var costRow = find(firstCard, "operationCostRow0")
                    check(costRow.y >= costTitle.y + costTitle.height, "cost title overlaps a cost row")
                    root.width = 660; root.height = 800; break
                case 4:
                    check(page.content_height > page.height, "scroll height missing")
                    screenshot("item-narrow")
                    page.removeOperation(0)
                    break
                case 5:
                    check(page.eledata.operations.length === 1 && page.eledata.operations[0].title === "", "operation deletion reindexed incorrectly")
                    var remaining = find(find(page, "operationCard0"), "operationTitle")
                    remaining.text = "剩余操作"; remaining.editingFinished()
                    check(JSON.parse(file.read(project + "/Item/example.xcseItem")).operations[0].title === "剩余操作", "reindexed edit went to wrong operation")
                    show(displayPage, "Display", "example")
                    break
                case 6:
                    check(page.dataLoaded, page.dataError)
                    var editor = find(page, "operationFormatEditor")
                    check(editor && editor.value.order === "title_then_cost", "operation format disconnected")
                    check(page.eledata.operation.enabled === false && page.eledata.operation.separator === ""
                        && page.eledata.frame.separator === "" && page.eledata.member.middle === "", "display has presets")
                    check(editor.visible && editor.height > 0, "disabled operation member editor is collapsed")
                    check(find(editor,"pairProperties").options.length === 5, "cost separator still inside operation members")
                    var enable = find(page,"operationFormatEnabled")
                    enable.checked = true; enable.toggled(true)
                    page.eledata.frame.separator = "\n\n"
                    page.eledata.member.middle = " × "
                    var tabs = find(editor, "pairProperties")
                    tabs.selectOption(2)
                    check(typeof find(editor,"displayTextInput").isSyntaxError === "function", "JSON editor is not the original single-line input")
                    find(editor, "displayTextInput").setContent(" → ")
                    var frameProperties = find(page,"frameProperties")
                    check(frameProperties.options[2] === "分隔文本" && frameProperties.options[3] === "代价分隔", "frame separators not distinct")
                    frameProperties.selectOption(3)
                    var separatorEditor = find(page,"frameTextEditor")
                    check(separatorEditor.caption === "同一操作内的代价分隔", "cost separator scope is unclear")
                    find(separatorEditor,"displayTextInput").setContent(" + ")
                    frameProperties.selectOption(2)
                    check(separatorEditor.caption === "操作之间的分隔", "overall separator scope is unclear")
                    tabs.selectOption(0)
                    find(editor, "displayTextInput").setContent('{"text":"• ","color":"green"}')
                    tabs.selectOption(1)
                    var style = find(editor, "pairTextStyle")
                    style.color = "gold"; style.propertyEdited()
                    check(JSON.parse(file.read(project + "/Display/example.xcseDisplay")).operation.middle === " → ", "display save")
                    var storedDisplay = JSON.parse(file.read(project + "/Display/example.xcseDisplay"))
                    check(storedDisplay.operation.head.indexOf('"green"') >= 0 && storedDisplay.operation.title.color === "gold", "JSON popup or text style not saved")
                    check(storedDisplay.operation.separator === " + " && storedDisplay.frame.separator === "\n\n", "moving separator changed its storage")
                    var preview = find(page, "operationsPreview")
                    var text = preview.renderedComponent.extra.map(function(s) { return s.text }).join("")
                    check(text.indexOf("操作1 → 代价1 × 1") >= 0 && text.indexOf("\n\n• 操作2") >= 0, "two-layer preview incorrect: " + text)
                    check(preview.width <= page.width - 64, "preview overflows")
                    screenshot("display-narrow")
                    break
                case 7: root.width = 1440; root.height = 1000; break
                case 8:
                    var panels = page.children.filter(function(child) { return typeof child.title === "string" && child.min_width !== undefined })
                    panels.forEach(function(panel) {
                        check(panel.x >= 16 && panel.x + panel.width <= page.width - 16 + 1, "panel alignment: " + panel.title + " x=" + panel.x + " width=" + panel.width)
                    })
                    var previewPanel = find(page,"displayPreviewBar")
                    var operationPanel = find(page,"displayOperationBar")
                    var memberPanel = find(page,"displayMemberBar")
                    var framePanel = find(page,"displayFrameBar")
                    var hintPanel = find(page,"displayHintBar")
                    check(page.layout && panels.length === 5, "three-column layout not active")
                    check(operationPanel.title === "操作组成员" && memberPanel.title === "代价组成员", "member titles not updated")
                    check(Math.abs(previewPanel.width - operationPanel.width * 2 - 16) < 1, "preview is not two columns wide")
                    check(Math.abs(framePanel.x - previewPanel.x - previewPanel.width - 16) < 1 && framePanel.y === previewPanel.y, "frame not to right of preview")
                    check(operationPanel.y === previewPanel.y + previewPanel.height + 16 && memberPanel.y === operationPanel.y, "member panels not below preview")
                    check(operationPanel.height === memberPanel.height && operationPanel.width === memberPanel.width, "member panel sizes differ")
                    check(hintPanel.x === framePanel.x && hintPanel.y === framePanel.y + framePanel.height + 16, "hints not below frame")
                    check(find(page,"operationFormatEnabled").y === 18, "enable checkbox not in top right")
                    screenshot("display-wide")
                    Global.animationSpeed = 1
                    activeCard = operationPanel
                    check(activeCard, "operation format panel not found")
                    find(find(page,"operationFormatEditor"),"pairProperties").selectOption(0)
                    activeInput = find(find(page,"operationFormatEditor"),"displayTextInput")
                    check(activeInput.visible, "Display resize input is hidden")
                    observedResizeFrame = false
                    activeInput.height = 256
                    break
                case 9:
                    check(observedResizeFrame, "no rendered Display resize frames were checked")
                    activeInput = null; activeCard = null
                    var disable = find(page,"operationFormatEnabled")
                    var beforeHeight = find(page,"displayOperationBar").height
                    disable.checked = false; disable.toggled(false)
                    check(find(page,"operationFormatEditor").visible && find(page,"displayOperationBar").height === beforeHeight, "disabled operation member editor collapsed")
                    check(find(page,"displayOperationBar").height === find(page,"displayMemberBar").height, "disabled member panel sizes differ")
                    check(find(page,"frameTextEditor").caption === "操作之间的分隔", "operation separator changed scope when names were hidden")
                    var flat = find(page,"operationsPreview").renderedComponent.extra.map(function(s) {return s.text}).join("")
                    check(flat === "• 代价1 × 1 + 代价2 × 2 + 代价3 × 3\n\n• 代价1 × 1 + 代价2 × 2 + 代价3 × 3", "name toggle changed grouping or separators: " + flat)
                    show(itemPage,"Item","example")
                    Global.animationSpeed = 1
                    timer.interval = 30
                    phaseStart = Date.now()
                    break
                case 10:
                    if (Date.now() - phaseStart < 500) { --root.step; return }
                    activeCard = find(page,"operationCard0")
                    var execute = find(activeCard,"executeKind")
                    execute.selected = 2; execute.clicked()
                    phaseStart = Date.now()
                    break
                case 11:
                    var panel = find(activeCard,"executePanel")
                    check(find(activeCard,"operationCardFrame").height === activeCard.height, "frame detached during reveal")
                    if (Date.now() - phaseStart < 170) { --root.step; return }
                    activeInput = find(activeCard,"operationExecuteValue")
                    check(panel.height >= activeInput.height, "execute panel height not expanded")
                    activeInput.height = 256
                    phaseStart = Date.now()
                    break
                case 12:
                    var actualInput = find(activeInput,"variableTextAreaInput")
                    check(Math.abs(actualInput.height - (activeInput.height - 35)) < 1, "input and outer height use different animations")
                    if (Date.now() - phaseStart < 170) { --root.step; return }
                    activeInput.height = 128
                    phaseStart = Date.now()
                    break
                case 13:
                    if (Date.now() - phaseStart < 170) { --root.step; return }
                    check(observedResizeFrame, "no rendered resize frames were checked")
                    page.addOperation()
                    check(page.eledata.operations.length === 2 && page.operationAdding, "add animation did not start")
                    phaseStart = Date.now()
                    break
                case 14:
                    var addedCard = find(page,"operationCard1")
                    var addingElapsed = Date.now() - phaseStart
                    if (addingElapsed > 20 && addingElapsed < 180) {
                        check(addedCard.appearing && addedCard.insertionProgress > 0 && addedCard.insertionProgress < 1, "add animation has no intermediate frames")
                        check(addedCard.height > 0 && addedCard.height < addedCard.contentHeight, "new card did not expand")
                        check(find(addedCard,"operationCardFrame").height === addedCard.height, "new card frame did not follow its expansion")
                        checkButtonColors(find(activeCard,"triggerKind"))
                        observedInsertion = true
                    }
                    if (addingElapsed < 280) { --root.step; return }
                    check(observedInsertion && !page.operationAdding && addedCard.height === addedCard.contentHeight, "add animation did not finish")
                    page.addOperation(false)
                    activeCard.requestRemove()
                    check(page.eledata.operations.length === 3, "delete removed row before slide animation")
                    phaseStart = Date.now()
                    break
                case 15:
                    var elapsed = Date.now() - phaseStart
                    if (elapsed > 20 && elapsed < 180) {
                        check(find(page,"operationInputGuard").visible, "delete input guard missing")
                        checkButtonColors(find(activeCard,"triggerKind"))
                        checkButtonColors(find(find(page,"operationCard1"),"triggerKind"))
                        checkButtonColors(find(find(page,"operationCard2"),"triggerKind"))
                        var movingFrame = find(activeCard,"operationCardFrame")
                        check(movingFrame.x > 0 && movingFrame.x < activeCard.width, "right-slide animation missing")
                        observedMotion = true
                    }
                    if (elapsed < 370) { --root.step; return }
                    check(observedMotion && page.eledata.operations.length === 2, "animated operation delete failed")
                    check(find(find(page,"operationCard0"),"operationNumber").xcText === "操作1", "operation number not reindexed")
                    activeCard = find(page,"operationCard0")
                    activeCard.addCost(); activeCard.addCost()
                    phaseStart = Date.now()
                    break
                case 16:
                    if (Date.now() - phaseStart < 80) { --root.step; return }
                    find(find(activeCard,"operationCostRow0"),"removeCostButton").clicked()
                    phaseStart = Date.now()
                    break
                case 17:
                    if (Date.now() - phaseStart < 180) checkButtonColors(find(activeCard,"triggerKind"))
                    if (Date.now() - phaseStart < 370) { --root.step; return }
                    check(page.eledata.operations[0].cost.length === 1, "animated cost delete failed")
                    screenshot("item-animations-restored")
                    break
                case 18:
                    console.log("OPERATIONS_UI_SMOKE_PASSED")
                    Qt.exit(0)
                }
            } catch (error) { console.error("OPERATIONS_UI_SMOKE_FAILED", error); Qt.exit(1) }
        }
    }
}
