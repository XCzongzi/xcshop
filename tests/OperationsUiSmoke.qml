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
    property bool trackingExecution: false
    property int executionAnimationFrames: 0
    property var swapPrevious: null
    property var swapCurrent: null
    property bool trackingSwap: false
    property bool observedSwap: false
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
    function optionButton(item, label) {
        if (item.text === label && item.btnSelected !== undefined) return item
        for (var i = 0; i < item.children.length; ++i) {
            var result = optionButton(item.children[i], label)
            if (result) return result
        }
        return null
    }
    function selectExecution(card, index) {
        var radio = find(card,"executeKind")
        var button = optionButton(radio,radio.options[index])
        check(button, "execution option button missing")
        button.forceActiveFocus()
        button.clicked()
        check(radio.selected === index, "execution option not selected")
    }
    function show(component, kind, name) {
        trackingExecution = false
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
        try {
            if (trackingSwap && page.operationMoving) {
                check(find(page,"operationInputGuard").visible,"swap does not guard input")
                if (swapPrevious.listShift > 0 && swapCurrent.listShift < 0)
                    observedSwap = true
                for (var card of [swapPrevious,swapCurrent]) {
                    var remove=find(card,"removeOperationButton")
                    check(Qt.colorEqual(remove.color,remove.btnbackground),"swap changed delete button color")
                    check(Qt.colorEqual(find(card,"moveOperationUpButton").color,Colors.transparent),"swap filled move button background")
                }
                checkButtonColors(swapPrevious)
                checkButtonColors(swapCurrent)
            }
            if (trackingExecution) {
                for (var index = 0; index < page.eledata.operations.length; ++index) {
                    var card = find(page,"operationCard"+index)
                    var trigger = find(card,"operationTrigger")
                    var panel = find(card,"executePanel")
                    check(Math.abs(find(card,"operationCardFrame").height-card.height) < 1,"execution card frame height mismatch")
                    check(trigger.mapToItem(card,Qt.point(0,trigger.height)).y <= card.height+1,"execution fields clipped by card")
                    if (panel.visible)
                        check(panel.y+panel.height <= trigger.height+1,"execution panel clipped by trigger editor")
                    if (index+1 < page.eledata.operations.length) {
                        var next = find(page,"operationCard"+(index+1))
                        check(next.y >= card.y+card.height+11,"execution resize overlaps the next card")
                    }
                    if (panel.animating) executionAnimationFrames++
                }
            }
            if (!activeCard || !activeInput || !activeInput.resizing) return
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
                    check(page.eledata.operations.every(function(op) { return op.successHint === true && op.failHint === true }), "new operation feedback defaults")
                    check(page.eledata.operations.every(function(op) { return op.returnOnSuccess === false }), "return-on-success must default off")
                    check(find(card,"operationCardHeader").height === 32, "original header strip missing")
                    check(find(card,"operationNumber").xcText === "操作1", "number must be in header control area")
                    var title = find(card, "operationTitle")
                    title.text = "左键购买"; title.editingFinished()
                    find(card, "operationShowInDisplay").checked = false
                    find(card, "operationShowInDisplay").toggled(false)
                    find(card, "operationSuccessHint").toggle()
                    find(card, "operationReturnOnSuccess").toggle()
                    check(!find(card,"operationSuccessHint").checked && find(card,"operationFailHint").checked, "feedback switches are not independent")
                    find(find(page,"operationCard1"), "operationFailHint").toggle()
                    card.addCost(); card.addCost(); card.removeCost(0)
                    var saved = JSON.parse(file.read(project + "/Item/example.xcseItem"))
                    check(saved.operations.length === 3 && saved.operations[0].title === "左键购买", "operation title save")
                    check(saved.operations[0].showInDisplay === false && saved.operations[0].cost.length === 1, "operation cost or visibility save")
                    check(saved.operations[0].successHint === false && saved.operations[0].failHint === true
                        && saved.operations[1].successHint === true && saved.operations[1].failHint === false, "feedback switches save")
                    check(saved.operations[0].returnOnSuccess === true && saved.operations[1].returnOnSuccess === false,"return-on-success save")
                    check(saved.cost === undefined && saved.trigger === undefined, "legacy roots persisted")
                    page.removeOperation(1)
                    screenshot("item-wide")
                    break
                case 3:
                    var firstCard = find(page, "operationCard0")
                    check(find(firstCard,"operationReturnOnSuccess").checked,"return switch reset after other operation edits")
                    var costTitle = find(firstCard, "operationCostTitle")
                    var costRow = find(firstCard, "operationCostRow0")
                    check(costRow.y >= costTitle.y + costTitle.height, "cost title overlaps a cost row")
                    root.width = 440; root.height = 800; break
                case 4:
                    check(page.content_height > page.height, "scroll height missing")
                    var card = find(page,"operationCard0")
                    var options = find(card,"operationOptions")
                    for (var control of ["operationShowInDisplay","operationSuccessHint","operationFailHint","operationReturnOnSuccess"]) {
                        var checkbox = find(card,control)
                        check(checkbox.x + checkbox.width <= options.width + 1 && checkbox.y + checkbox.height <= options.height + 1, "feedback checkbox overflows narrow card")
                    }
                    check(find(card,"operationTrigger").mapToItem(card,0,0).y >= options.mapToItem(card,0,options.height).y, "feedback row overlaps trigger controls")
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
                    check(find(editor,"pairProperties").options.length === 4
                        && find(editor,"pairProperties").options.indexOf("代价文本") < 0, "operation members still expose cost text editing")
                    check(page.eledata.operation.cost === undefined, "duplicate operation cost style persisted")
                    check(find(find(page,"costFormatEditor"),"pairProperties").options.length === 5, "cost member controls changed")
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
                case 7:
                    var operationEditor = find(page,"operationFormatEditor")
                    check(operationEditor.editingStyle && !find(operationEditor,"displayTextInput").visible, "style tab shows the previous text editor")
                    var opTabs = find(operationEditor,"pairProperties")
                    opTabs.selectOption(3)
                    find(operationEditor,"displayTextInput").setContent(";")
                    check(page.eledata.operation.end === ";" && page.eledata.operation.middle === " → ", "last operation tab writes the wrong property")
                    root.width = 1440; root.height = 1000; break
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
                    check(flat === "代价1 × 1 + 代价2 × 2 + 代价3 × 3\n\n代价1 × 1 + 代价2 × 2 + 代价3 × 3", "disabled operation members leaked wrapping or changed separators: " + flat)
                    check(find(page,"operationsPreview").renderedComponent.extra.every(function(part) { return part.color !== "gold" }), "disabled title style leaked")
                    var restored = find(page,"operationFormatEnabled")
                    restored.checked = true; restored.toggled(true)
                    check(find(page,"operationsPreview").renderedComponent.extra.map(function(s) {return s.text}).join("").indexOf("• 操作1 → ") === 0, "reenabling operation members lost their settings")
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
                    var seed = Schema.item()
                    seed.operations = [Schema.operation("命令"),Schema.operation("函数"),Schema.operation("物品")]
                    seed.operations[0].trigger.execute = {kind:"command",value:"say saved command"}
                    seed.operations[1].trigger.execute = {kind:"function",value:"example:saved\nexample:second"}
                    seed.operations[0].trigger.mode = {kind:"drop_item",quantity:"all"}
                    seed.operations[1].trigger.mode = {kind:"take_item",filter:{kind:"quantity",mode:"custom",amount:"7"}}
                    seed.operations[0].successHint = false
                    seed.operations[0].returnOnSuccess = true
                    seed.operations[1].failHint = false
                    check(file.writeAtomic(project+"/Item/execution.xcseItem",JSON.stringify(seed)),"execution seed")
                    show(itemPage,"Item","execution")
                    phaseStart = Date.now()
                    break
                case 19:
                    if (Date.now()-phaseStart < 500) { --root.step; return }
                    check(page.dataLoaded,page.dataError)
                    check(!find(find(page,"operationCard0"),"operationSuccessHint").checked
                        && find(find(page,"operationCard0"),"operationFailHint").checked
                        && find(find(page,"operationCard1"),"operationSuccessHint").checked
                        && !find(find(page,"operationCard1"),"operationFailHint").checked, "feedback switches did not reopen correctly")
                    check(find(find(page,"operationCard0"),"operationReturnOnSuccess").checked
                        && !find(find(page,"operationCard1"),"operationReturnOnSuccess").checked,"return-on-success did not reopen correctly")
                    check(find(find(page,"operationCard0"),"executeKind").selected === 1,"saved command reopened as grant_item")
                    check(find(find(page,"operationCard1"),"executeKind").selected === 2,"saved function reopened as grant_item")
                    check(find(find(page,"operationCard0"),"operationCommandValue").text === "say saved command","command text not loaded")
                    check(find(find(page,"operationCard1"),"operationExecuteValue").getContent() === "example:saved\nexample:second","function text not loaded")
                    check(find(find(page,"operationCard0"),"triggerKind").selected === 1,"saved drop trigger reset")
                    check(find(find(page,"operationCard1"),"triggerAmount").text === "7","saved custom amount reset")
                    trackingExecution = true
                    selectExecution(find(page,"operationCard2"),1)
                    var command = find(find(page,"operationCard2"),"operationCommandValue")
                    command.text = "say edited command"; command.editingFinished()
                    check(JSON.parse(file.read(project+"/Item/execution.xcseItem")).operations[2].trigger.execute.kind === "command","command kind not saved")
                    phaseStart = Date.now()
                    break
                case 20:
                    if (Date.now()-phaseStart < 200) { --root.step; return }
                    var card = find(page,"operationCard2")
                    var commandPanel = find(card,"executePanel")
                    check(Math.abs(commandPanel.height-find(card,"operationCommandValue").height-8) < 1,"command panel retained function height: "+commandPanel.height)
                    show(itemPage,"Item","execution")
                    phaseStart = Date.now()
                    break
                case 21:
                    if (Date.now()-phaseStart < 500) { --root.step; return }
                    var card = find(page,"operationCard2")
                    check(find(card,"executeKind").selected === 1,"edited command reopened as grant_item")
                    check(find(card,"operationCommandValue").text === "say edited command","edited command lost")
                    trackingExecution = true
                    selectExecution(card,2)
                    var functionEditor = find(card,"operationExecuteValue")
                    var input = find(functionEditor,"variableTextAreaInput")
                    input.text = "example:edited\nexample:second"; input.editingFinished()
                    phaseStart = Date.now()
                    break
                case 22:
                    if (Date.now()-phaseStart < 200) { --root.step; return }
                    var card = find(page,"operationCard2")
                    check(Math.abs(find(card,"executePanel").height-find(card,"operationExecuteValue").height-8) < 1,"function panel height incorrect")
                    var saved = JSON.parse(file.read(project+"/Item/execution.xcseItem")).operations[2].trigger.execute
                    check(saved.kind === "function" && saved.value === "example:edited\nexample:second","edited function not saved")
                    show(itemPage,"Item","execution")
                    phaseStart = Date.now()
                    break
                case 23:
                    if (Date.now()-phaseStart < 500) { --root.step; return }
                    var card = find(page,"operationCard2")
                    check(find(card,"executeKind").selected === 2,"edited function reopened as grant_item")
                    check(find(card,"operationExecuteValue").getContent() === "example:edited\nexample:second","edited function lost")
                    trackingExecution = true
                    selectExecution(card,0)
                    phaseStart = Date.now()
                    break
                case 24:
                    if (Date.now()-phaseStart < 200) { --root.step; return }
                    var card = find(page,"operationCard2")
                    check(find(card,"executePanel").height === 0,"grant_item did not collapse execution panel")
                    check(JSON.parse(file.read(project+"/Item/execution.xcseItem")).operations[2].trigger.execute.value === undefined,"grant_item kept hidden input")
                    selectExecution(card,1)
                    phaseStart = Date.now()
                    break
                case 25:
                    if (Date.now()-phaseStart < 35) { --root.step; return }
                    selectExecution(find(page,"operationCard2"),2)
                    phaseStart = Date.now()
                    break
                case 26:
                    if (Date.now()-phaseStart < 35) { --root.step; return }
                    selectExecution(find(page,"operationCard2"),0)
                    phaseStart = Date.now()
                    break
                case 27:
                    if (Date.now()-phaseStart < 35) { --root.step; return }
                    selectExecution(find(page,"operationCard2"),1)
                    phaseStart = Date.now()
                    break
                case 28:
                    if (Date.now()-phaseStart < 200) { --root.step; return }
                    var card = find(page,"operationCard2")
                    check(Math.abs(find(card,"executePanel").height-40) < 1,"rapid switches left an old animation target")
                    check(find(card,"operationCommandValue").text === "","command input retained a previous value")
                    root.width = 660
                    selectExecution(card,2)
                    activeCard = card; activeInput = find(card,"operationExecuteValue")
                    activeInput.height = 256
                    phaseStart = Date.now()
                    break
                case 29:
                    if (Date.now()-phaseStart < 220) { --root.step; return }
                    var card = find(page,"operationCard2")
                    check(Math.abs(find(card,"executePanel").height-264) < 1,"narrow card did not follow editor resizing")
                    var input = find(find(card,"operationExecuteValue"),"variableTextAreaInput")
                    input.text = "example:cleared"; input.editingFinished()
                    selectExecution(card,1)
                    phaseStart = Date.now()
                    break
                case 30:
                    if (Date.now()-phaseStart < 180) { --root.step; return }
                    selectExecution(find(page,"operationCard2"),2)
                    phaseStart = Date.now()
                    break
                case 31:
                    if (Date.now()-phaseStart < 180) { --root.step; return }
                    var card = find(page,"operationCard2")
                    check(find(card,"operationExecuteValue").getContent() === "","function input retained a stale value after changing its execution kind")
                    check(executionAnimationFrames > 0,"execution transition animation not observed")
                    screenshot("item-execution-narrow")
                    selectExecution(card,0)
                    show(itemPage,"Item","execution")
                    phaseStart = Date.now()
                    break
                case 32:
                    if (Date.now()-phaseStart < 500) { --root.step; return }
                    check(find(find(page,"operationCard2"),"executeKind").selected === 0,"grant_item did not persist")
                    check(find(find(page,"operationCard2"),"executePanel").height === 0,"grant_item reopened expanded")
                    Global.animationSpeed = 1
                    root.width = 1200
                    var seed = Schema.item()
                    seed.operations = [Schema.operation("上方"),Schema.operation("下方"),Schema.operation("第三项")]
                    seed.operations[0].returnOnSuccess = true
                    seed.operations[0].successHint = false
                    seed.operations[0].trigger.execute = {kind:"command",value:"say upper"}
                    seed.operations[1].cost = [{element:"Cost/example.xcseCost",amount:"7"}]
                    seed.operations[1].trigger.execute = {kind:"function",value:"example:lower\nexample:next"}
                    check(file.writeAtomic(project+"/Item/moving.xcseItem",JSON.stringify(seed)),"moving seed")
                    show(itemPage,"Item","moving")
                    phaseStart = Date.now()
                    break
                case 33:
                    if (Date.now()-phaseStart < 650) { --root.step; return }
                    swapPrevious = find(page,"operationCard0")
                    swapCurrent = find(page,"operationCard1")
                    check(Math.abs(swapPrevious.height-swapCurrent.height)>30,"swap test needs different card heights")
                    var up = find(swapCurrent,"moveOperationUpButton")
                    var remove = find(swapCurrent,"removeOperationButton")
                    check(up.height === remove.height && up.mapToItem(swapCurrent,0,0).y === remove.mapToItem(swapCurrent,0,0).y,"up button is not header height")
                    check(Math.abs(up.mapToItem(swapCurrent,up.width,0).x-remove.mapToItem(swapCurrent,0,0).x)<1,"up button is not immediately left of delete")
                    check(Qt.colorEqual(up.btnbackground,Colors.transparent),"up button base is not transparent")
                    check(!find(swapPrevious,"moveOperationUpButton").enabled,"first operation can move up")
                    trackingSwap = true
                    up.clicked()
                    check(page.operationMoving,"swap animation did not start")
                    page.moveOperationUp(2); page.addOperation()
                    check(page.eledata.operations.length===3,"adding is not guarded during swap")
                    phaseStart=Date.now()
                    break
                case 34:
                    if (page.operationMoving) { --root.step; return }
                    trackingSwap=false
                    check(observedSwap,"both cards did not animate")
                    check(find(page,"operationCard0")===swapCurrent && find(page,"operationCard1")===swapPrevious,"swap recreated or misidentified card delegates")
                    check(swapPrevious.listShift===0 && swapCurrent.listShift===0,"swap left a residual translation")
                    var saved=JSON.parse(file.read(project+"/Item/moving.xcseItem"))
                    check(saved.operations[0].title==="下方" && saved.operations[1].title==="上方" && saved.operations[2].title==="第三项","swap saved wrong order")
                    check(saved.operations[0].cost[0].amount==="7" && saved.operations[1].returnOnSuccess && !saved.operations[1].successHint,"swap detached operation settings")
                    check(find(swapCurrent,"operationNumber").xcText==="操作1" && !find(swapCurrent,"moveOperationUpButton").enabled,"header index did not follow swap")
                    var title=find(swapPrevious,"operationTitle")
                    title.text="上方已编辑"; title.editingFinished()
                    check(JSON.parse(file.read(project+"/Item/moving.xcseItem")).operations[1].title==="上方已编辑","editing after swap wrote to wrong operation")
                    screenshot("item-swap")
                    find(find(page,"operationCard2"),"moveOperationUpButton").clicked()
                    break
                case 35:
                    if (page.operationMoving) { --root.step; return }
                    check(page.eledata.operations[1].title==="第三项" && page.eledata.operations[2].title==="上方已编辑","second swap failed")
                    find(find(page,"operationCard1"),"moveOperationUpButton").clicked()
                    break
                case 36:
                    if (page.operationMoving) { --root.step; return }
                    check(page.eledata.operations[0].title==="第三项","repeated move to first failed")
                    find(find(page,"operationCard1"),"removeOperationButton").clicked()
                    phaseStart=Date.now()
                    break
                case 37:
                    if (page.operationDeleting || Date.now()-phaseStart<500) { --root.step; return }
                    check(page.eledata.operations.length===2 && page.eledata.operations[1].title==="上方已编辑","delete after swap removed wrong operation")
                    show(itemPage,"Item","moving")
                    phaseStart=Date.now()
                    break
                case 38:
                    if (Date.now()-phaseStart < 650) { --root.step; return }
                    check(page.eledata.operations[0].title==="第三项" && page.eledata.operations[1].title==="上方已编辑","reopening lost moved order")
                    check(find(find(page,"operationCard1"),"operationReturnOnSuccess").checked,"reopening moved operation lost return switch")
                    console.log("OPERATIONS_UI_SMOKE_PASSED")
                    Qt.exit(0)
                }
            } catch (error) { console.error("OPERATIONS_UI_SMOKE_FAILED", error); Qt.exit(1) }
        }
    }
}
