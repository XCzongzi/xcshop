import QtQuick
import QtQuick.Window
import xcshop
import "../js/WorkspaceSchema.js" as Schema

Window {
    id: root
    visible: true
    width: 1200
    height: 900
    property string project: SMOKE_DIR + "/content-bar"
    property var page: null
    property var card: null
    property int scene: -1
    property double started: 0
    property real previousHeight: 0
    property bool previousExpanded: false
    property int animationFrames: 0
    property bool changedHeight: false
    readonly property var scenes: ["late", "delayed", "instant", "display-wide", "display-narrow", "item-wide", "item-narrow"]

    XCFile { id: file }
    Component { id: barComponent; ContentBar { width: root.width - 32; contentHeight: 80 } }
    Component { id: displayComponent; PageOnDisplay {} }
    Component { id: itemComponent; PageOnItem {} }

    function check(value, message) {
        if (!value) throw new Error(scenes[scene] + ": " + message)
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) {
            var found = find(child, name)
            if (found) return found
        }
        return null
    }
    function nextScene() {
        card = null
        if (page) page.destroy()
        if (++scene === scenes.length) {
            console.log("CONTENT_BAR_UI_SMOKE_PASSED")
            Qt.exit(0)
            return
        }
        var name = scenes[scene]
        root.width = name.endsWith("narrow") ? 660 : 1600
        changedHeight = false
        animationFrames = 0
        previousHeight = 0
        previousExpanded = false
        if (scene < 3) {
            page = barComponent.createObject(root.contentItem, {
                delayExpand: name === "delayed",
                expanded: name === "instant"
            })
            card = page
            if (name === "delayed") check(card.height === 0, "delayed card opened before expand()")
            if (name === "instant") check(card.height === 80, "expanded card did not open immediately")
        } else {
            var display = name.startsWith("display")
            Global.current_element = display ? "Display" : "Item"
            Global.set_file([], "example")
            page = (display ? displayComponent : itemComponent).createObject(root.contentItem, {
                width: root.width, height: root.height
            })
            check(page && page.dataLoaded, "page did not load")
            card = find(page, display ? "displayPreviewBar" : "operationsBar")
        }
        check(card, "card missing")
        started = Date.now()
    }
    onFrameSwapped: {
        if (!card) return
        try {
            if (card.expanded && !previousExpanded && animationFrames > 0) {
                check(Math.abs(card.height - previousHeight) < Math.max(12, card.contentHeight * 0.05),
                      "height jumped at animation completion: " + previousHeight + " -> " + card.height)
            }
            if (!card.expanded && card.height > 0) ++animationFrames
            previousHeight = card.height
            previousExpanded = card.expanded
        } catch (error) {
            console.error("CONTENT_BAR_UI_SMOKE_FAILED", error)
            Qt.exit(1)
        }
    }
    Component.onCompleted: {
        Global.animationSpeed = 1
        Global.project_location = project
        file.folder(project + "/Item")
        file.folder(project + "/Display")
        var item = Schema.item()
        for (var i = 0; i < 3; ++i) {
            var operation = Schema.operation("操作 " + i)
            operation.trigger.execute = {kind: "function", value: "example:run"}
            operation.cost = [{element: "", amount: "1"}, {element: "", amount: "2"}]
            item.operations.push(operation)
        }
        var display = Schema.display()
        display.operation.enabled = true
        display.frame.head = Array(15).join("预览文本\n")
        file.writeAtomic(project + "/Item/example.xcseItem", JSON.stringify(item))
        file.writeAtomic(project + "/Display/example.xcseDisplay", JSON.stringify(display))
        nextScene()
    }
    Timer {
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            try {
                if (!root.card) return
                var elapsed = Date.now() - root.started
                if (root.scene < 3 && !root.changedHeight && elapsed >= 80) {
                    if (root.scenes[root.scene] === "delayed") {
                        root.check(root.card.height === 0, "delayed card did not stay closed")
                        root.card.expand()
                    }
                    // Simulate content whose layout settles after the animation starts.
                    root.card.contentHeight = 900
                    root.changedHeight = true
                }
                if (elapsed < 750) return
                root.check(root.card.expanded, "animation did not finish")
                root.check(Math.abs(root.card.height - root.card.contentHeight) < 1, "final height differs from content")
                if (root.scenes[root.scene] !== "instant")
                    root.check(root.animationFrames >= 4, "expansion did not render intermediate heights")
                root.card.contentHeight += 40
                root.check(Math.abs(root.card.height - root.card.contentHeight) < 1, "expanded card no longer follows content")
                root.nextScene()
            } catch (error) {
                console.error("CONTENT_BAR_UI_SMOKE_FAILED", error)
                Qt.exit(1)
            }
        }
    }
}
