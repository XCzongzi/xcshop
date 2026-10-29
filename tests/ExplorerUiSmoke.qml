pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop
import "qrc:/qt/qml/xcshop/js/WorkspaceSchema.js" as Schema

Window {
    id: root
    visible: true
    width: 1100
    height: 760
    color: Colors.background_n
    readonly property string project: SMOKE_DIR + "/元素管理测试"
    property var tree: null
    property var controls: null
    property var lastMoves: []
    XCFile { id: files }
    Component { id: itemPage; PageOnItem {} }
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Colors.background_n
        NumberAnimation on opacity { from: 0.999; to: 1; duration: 500; loops: Animation.Infinite }
        ElementExplorer { id: explorer; barWidth: 245; isShowing: true }
        FileControls {
            id: pathBar
            x: explorer.x + explorer.width
            onLocateCurrentElementRequested: explorer.locateCurrentElement()
        }
        Loader {
            id: editor
            x: pathBar.x; y: 30
            width: parent.width - x; height: parent.height - y - relay.height
        }
        ElementRelayBar {
            id: relay
            x: pathBar.x; y: parent.height - height
            width: parent.width - x
            workspaceActive: true
        }
    }
    PopupLoader { id: popup; anchors.fill: parent }
    ContextMenu { id: menu; z: 1001; onClosed: SignalBus.contextMenuClosed() }
    Connections {
        target: SignalBus
        function onSendToMain(kind, parameters) {
            if (kind === "Popup.show")
                popup.open(parameters.component, parameters.properties, parameters.callback)
            else if (kind === "switched_file") {
                editor.sourceComponent = null
                editor.sourceComponent = itemPage
            }
        }
        function onContextMenuRequested(target, x, y, items, component) {
            menu.menuItems = items
            menu.contentComponent = component
            menu.openFor(target, x, y)
        }
        function onElementFilesMoved(moves) { root.lastMoves = moves }
    }
    function check(condition, message) { if (!condition) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children || []) {
            var result = find(child, name)
            if (result) return result
        }
        return null
    }
    function input() {
        UiInput.settle(80)
        check(popup.item, "Naming dialog did not open")
        return find(popup.item, "popupTextInputField")
    }
    function enterName(name) {
        var field = input()
        field.text = name
        UiInput.key(field, Qt.Key_Return)
        UiInput.settle(80)
    }
    function cancel() {
        var field = input()
        UiInput.key(field, Qt.Key_Escape)
        UiInput.settle(80)
        check(!popup.item, "Escape did not close naming dialog")
    }
    function run() {
        tree = find(explorer, "explorerFileTree")
        controls = find(explorer, "explorerFileControls")
        check(tree && controls, "Explorer controls missing")
        check(files.folder(project + "/Item/rename-probe"), "Seed rename probe")
        check(files.rename(project + "/Item/rename-probe", project + "/Item/renamed-probe"), "Backend directory rename failed")
        var source = project + "/Item/原目录.v1"
        var target = project + "/Item/新目录.v2"
        var oldFile = source + "/子目录/示例.xcseItem"
        var newFile = target + "/子目录/示例.xcseItem"
        check(files.writeAtomic(oldFile, JSON.stringify(Schema.item())), "Seed active element")
        check(files.writeAtomic(source + "/other.xcseItem", "{}"), "Seed sibling element")
        check(files.folder(project + "/Item/已存在"), "Seed collision directory")
        Global.set_file("/原目录.v1/子目录", "示例")
        editor.sourceComponent = itemPage
        SignalBus.elementOpened("Item", oldFile, "示例")
        SignalBus.elementsAddToRelayRequested([oldFile], "favorites")
        UiInput.settle(150)

        // The path menu must locate the editor even while browsing elsewhere.
        tree.currentFolder = "/已存在"
        UiInput.rightClick(find(explorer, "explorerDirectoryPath"))
        check(menu.menuItems[0].text === "回到当前编辑的元素位置" && menu.menuItems[0].enabled,
              "Directory path context menu missing locate action")
        var locate = menu.menuItems[0].action
        menu.close(); locate()
        check(tree.currentFolder === "/原目录.v1/子目录", "Path menu did not locate active element")
        UiInput.settle(80)
        tree.currentFolder = ""
        var pathText = find(pathBar, "currentElementPath")
        UiInput.hover(pathText)
        UiInput.settle(40)
        check(pathText.font.underline, "Current element path did not underline on hover")
        check(!Qt.colorEqual(pathText.color, Colors.banned), "Current element path did not highlight on hover")
        UiInput.click(pathText)
        check(tree.currentFolder === "/原目录.v1/子目录", "Left click did not locate active element")
        UiInput.hover(pathText, false)
        UiInput.settle(40)
        check(!pathText.font.underline, "Path underline remained after pointer left")

        tree.currentFolder = ""
        UiInput.settle(80)
        tree.clipboardPaths = [oldFile]
        tree.selectDirectory(source)
        tree.forceActiveFocus()
        UiInput.key(tree, Qt.Key_F2)
        var field = input()
        check(field.activeFocus && field.selectedText === "原目录.v1", "Rename did not focus and select original folder name")
        enterName("已存在")
        check(popup.item && files.isDirectory(source), "Collision closed dialog or moved source")
        check(find(popup.item, "popupTextInputError").visible, "Collision error is not visible")
        enterName("../越界")
        check(popup.item && files.isDirectory(source), "Invalid folder name was accepted")
        enterName("新目录.v2")
        check(!popup.item && files.exists(newFile) && !files.isDirectory(source),
              "Folder rename failed: popup=" + !!popup.item + " destination=" + files.exists(newFile)
              + " source=" + files.isDirectory(source) + " error=" + (popup.item ? popup.item.errorText : ""))
        check(Global.get_filePath() === newFile, "Active element path was not updated")
        check(tree.clipboardPaths[0] === newFile && lastMoves.length === 2, "Nested moves or clipboard paths missing")
        check(editor.item && editor.item.dataLoaded && editor.item.updateDataOut(), "Editing renamed element failed")
        check(!files.isDirectory(source), "Saving recreated old directory")
        check(JSON.stringify(Global.elementRelayState(project)).indexOf(newFile) >= 0,
              "Relay record still points to old folder")
        check(tree.directoryContextMenuItems(target).some(function(entry) { return entry.text === "重命名…" }),
              "Folder context menu missing rename action")
        check(tree.renameDirectory(target, "新目录.v2") === "", "Unchanged name should succeed")

        // Folder and file creation must preserve existing entries and keyboard focus.
        tree.currentFolder = "/新目录.v2"
        tree.forceActiveFocus()
        UiInput.key(tree, Qt.Key_N, Qt.ControlModifier | Qt.ShiftModifier)
        field = input()
        check(field.activeFocus && !find(popup.item, "popupTextInputConfirm").enabled,
              "New folder did not autofocus or allowed empty name")
        for (var invalid of [" ", ".", "..", "con", "NUL.txt", "bad/name", "trailing."]) {
            field.text = invalid
            check(popup.item.validationError.length > 0, "Invalid filename accepted: " + invalid)
        }
        enterName("新建文件夹")
        check(files.isDirectory(target + "/新建文件夹") && tree.activeFocus, "New folder or focus restoration failed")
        controls.requestCreate(true)
        enterName("新建文件夹")
        check(popup.item, "Duplicate folder name accepted")
        cancel()
        check(tree.activeFocus, "Cancel did not restore explorer focus")
        tree.forceActiveFocus()
        UiInput.key(tree, Qt.Key_N, Qt.ControlModifier)
        enterName("新元素")
        var createdFile = target + "/新元素.xcseItem"
        var contents = files.read(createdFile)
        check(contents.length && JSON.parse(contents).operations !== undefined, "New element contents invalid")
        controls.requestCreate(false)
        enterName("新元素")
        check(popup.item && files.read(createdFile) === contents, "Duplicate creation overwrote element")
        cancel()

        controls.requestCreate(true)
        field = input()
        field.text = "键盘取消"
        UiInput.key(field, Qt.Key_Tab)
        UiInput.key(field, Qt.Key_Return)
        UiInput.settle(80)
        check(!popup.item && !files.isDirectory(target + "/键盘取消"), "Tab then Enter did not cancel")
        controls.requestCreate(true)
        field = input()
        field.text = "取消后不创建"
        UiInput.key(field, Qt.Key_Escape)
        UiInput.key(field, Qt.Key_Return)
        UiInput.settle(80)
        check(!popup.item && !files.isDirectory(target + "/取消后不创建"), "Enter during cancellation still created a folder")
        tree.currentFolder = "/不存在的目录"
        controls.requestCreate(true)
        enterName("保留输入")
        check(popup.item && popup.item.submissionError.length > 0 && input().text === "保留输入",
              "Write failure did not retain dialog and input")
        cancel()
        tree.currentFolder = "/新目录.v2"
        check(files.folder(target + "/empty"), "Seed empty directory")
        check(tree.renameDirectory(target + "/empty", "empty-renamed") === ""
              && files.isDirectory(target + "/empty-renamed"), "Empty folder rename failed")
        explorer.locateCurrentElement()
        check(tree.currentFolder === "/新目录.v2/子目录", "Locate after rename used stale folder")
        Global.set_file("*", "")
        check(!pathBar.canLocateCurrentElement && !explorer.canLocateCurrentElement,
              "Locate enabled without an active element")
        Global.set_file("/新目录.v2/子目录", "示例")
        controls.requestCreate(true)
        input().text = "商品分类"
        screenshot("dark", function() {
            Colors.applyColorScheme("glacier")
            screenshot("light", function() {
                console.log("EXPLORER_UI_SMOKE_PASSED")
                Qt.exit(0)
            })
        })
    }
    function screenshot(name, done) {
        UiInput.settle(100)
        contentItem.grabToImage(function(result) {
            try {
                check(result.saveToFile(SMOKE_OUTPUT_DIR + "/ui-explorer-" + name + ".png"), "Screenshot save failed")
                done()
            } catch (error) { console.error("EXPLORER_UI_SMOKE_FAILED", error); Qt.exit(1) }
        })
    }
    Component.onCompleted: {
        Global.animationSpeed = 20
        Global.settingsPath = SMOKE_DIR + "/settings.json"
        Global.project_location = project
        Global.current_element = "Item"
        Colors.applyColorScheme("midnight")
        Global.mainWindow_popupBackdrop = frame
        start.start()
    }
    Timer {
        id: start
        interval: 100
        onTriggered: {
            try { root.run() }
            catch (error) { console.error("EXPLORER_UI_SMOKE_FAILED", error); Qt.exit(1) }
        }
    }
}
