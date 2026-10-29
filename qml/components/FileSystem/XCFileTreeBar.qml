pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import xcshop

Item {
    id: root

    property string currentFolder: ""
    readonly property string currentDirectory: Global.normalizeElementPath(
                                                   Global.project_location + "/"
                                                   + Global.current_element + currentFolder)
    readonly property string filePath: "file:" + currentDirectory
    property var selectedPaths: []
    property string selectedDirectoryPath: ""
    property var clipboardPaths: []
    property int selectionAnchor: -1
    property bool operationMode: false
    property bool pendingOperation: false
    property bool contextMenuActive: false
    property FolderListModel folderFileModel: null
    property FolderListModel folderDirectoryModel: null

    signal floderSwitched()
    signal fileSwitched()
    signal createEntryRequested(bool isFolder)

    focus: true

    XCFile { id: fileOperations }

    function directionBack() {
        currentFolder = currentFolder.split("/").slice(0, -1).join("/")
        finishOperation()
        floderSwitched()
    }

    function moveEntriesToParentDirectory(paths) {
        if (!currentFolder.length)
            return
        var separator = currentDirectory.lastIndexOf("/")
        if (separator > 0)
            moveEntriesToDirectory(paths, currentDirectory.substring(0, separator))
    }

    function pathForFileName(fileName) {
        return currentDirectory + "/" + fileName
    }

    function selectedIndex(path) {
        var normalized = Global.normalizeElementPath(path)
        for (var i = 0; i < selectedPaths.length; ++i) {
            if (Global.normalizeElementPath(selectedPaths[i]) === normalized)
                return i
        }
        return -1
    }

    function isSelected(path) {
        return selectedIndex(path) >= 0
    }

    function isOpened(path) {
        return Global.normalizeElementPath(path)
                === Global.normalizeElementPath(Global.get_filePath())
    }

    // 打开标识和多选操作态是两套视觉状态。没有多选时，将当前目录中
    // 带打开标识的文件作为快捷键操作目标。
    function openedFileInCurrentFolder() {
        var openedPath = Global.normalizeElementPath(Global.get_filePath())
        var element = Global.parseElementPath(openedPath)
        if (!element || element.type !== Global.current_element
                || element.folder !== currentFolder)
            return ""
        return openedPath
    }

    function shortcutFileTargets() {
        if (selectedPaths.length)
            return selectedPaths.slice()
        var openedPath = openedFileInCurrentFolder()
        return openedPath.length ? [openedPath] : []
    }

    function beginOperation() {
        operationMode = true
    }

    function clearSelection() {
        selectedPaths = []
        selectedDirectoryPath = ""
        selectionAnchor = -1
    }

    function finishOperation() {
        clearSelection()
        operationMode = false
        pendingOperation = false
        contextMenuActive = false
        root.forceActiveFocus()
    }

    function selectOnly(path, index) {
        selectedDirectoryPath = ""
        selectedPaths = [Global.normalizeElementPath(path)]
        selectionAnchor = index
    }

    function selectDirectory(path) {
        beginOperation()
        selectedPaths = []
        selectedDirectoryPath = Global.normalizeElementPath(path)
        selectionAnchor = -1
    }

    function enterDirectory(path) {
        var normalized = Global.normalizeElementPath(path)
        var prefix = currentDirectory + "/"
        if (normalized.indexOf(prefix) !== 0)
            return
        currentFolder += "/" + normalized.substring(prefix.length)
        finishOperation()
        floderSwitched()
    }

    function toggleSelection(path, index) {
        beginOperation()
        var normalized = Global.normalizeElementPath(path)
        var next = selectedPaths.slice()
        var existing = selectedIndex(normalized)
        if (existing >= 0)
            next.splice(existing, 1)
        else
            next.push(normalized)
        selectedPaths = next
        selectionAnchor = index
    }

    function selectRange(index) {
        beginOperation()
        if (selectionAnchor < 0) {
            var firstName = folderFileModel.get(index, "fileName")
            selectOnly(pathForFileName(firstName), index)
            return
        }

        var start = Math.min(selectionAnchor, index)
        var end = Math.max(selectionAnchor, index)
        var paths = []
        for (var i = start; i <= end; ++i)
            paths.push(pathForFileName(folderFileModel.get(i, "fileName")))
        selectedPaths = paths
    }

    function selectAll() {
        beginOperation()
        var paths = []
        for (var i = 0; i < folderFileModel.count; ++i)
            paths.push(pathForFileName(folderFileModel.get(i, "fileName")))
        selectedPaths = paths
        selectionAnchor = paths.length ? 0 : -1
    }

    function prepareFileDrag(path, index, modifiers) {
        beginOperation()
        if (!(modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && !isSelected(path))
            selectOnly(path, index)
    }

    function handleFileClick(path, index, modifiers) {
        if (modifiers & Qt.ControlModifier) {
            toggleSelection(path, index)
            return
        }
        if (modifiers & Qt.ShiftModifier) {
            selectRange(index)
            return
        }

        selectOnly(path, index)
        openFile(path)
    }

    function openFile(path) {
        var element = Global.parseElementPath(path)
        if (!element)
            return
        Global.set_file(currentFolder, element.name)
        fileSwitched()
        SignalBus.elementOpened(element.type, element.path, element.name)
        SignalBus.sendToMain("switched_file", {})
        finishOperation()
    }

    function copySelection(paths) {
        clipboardPaths = (paths || selectedPaths).slice()
        finishOperation()
    }

    function pasteFiles(directoryPath) {
        var targetDirectory = directoryPath || currentDirectory
        var failed = 0
        for (var i = 0; i < clipboardPaths.length; ++i) {
            var sourceElement = Global.parseElementPath(clipboardPaths[i])
            if (!sourceElement || sourceElement.type !== Global.current_element) {
                ++failed
                continue
            }
            var destination = fileOperations.copyToDirectory(clipboardPaths[i], targetDirectory)
            if (!destination.length)
                ++failed
        }
        if (failed)
            showNotice("粘贴未完全成功", failed + " 个元素无法复制，源文件可能已移动或删除。")
        finishOperation()
    }

    function cloneFile(path) {
        var destination = fileOperations.clone(path)
        if (!destination.length) {
            showNotice("克隆失败", "无法克隆所选元素。")
            finishOperation()
            return
        }
        finishOperation()
    }

    function requestRename(path) {
        var element = Global.parseElementPath(path)
        if (!element)
            return
        pendingOperation = true
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupTextInput,
            "properties": {
                "title": "重命名元素",
                "content": "请输入新的元素名",
                "value": element.name,
                "confirmText": "重命名"
            },
            "callback": function(result) {
                if (result !== null && result !== undefined)
                    root.renameFile(path, String(result))
                root.finishOperation()
            }
        })
    }

    function renameFile(path, requestedName) {
        var name = requestedName.trim()
        if (!name.length || name === "." || name === ".." || /[\\/:*?"<>|]/.test(name)) {
            showNotice("名称无效", "元素名不能为空，且不能包含 \\ / : * ? \" < > |。")
            return
        }

        var element = Global.parseElementPath(path)
        if (!element || name === element.name)
            return
        var destination = currentDirectory + "/" + name + ".xcse" + element.type
        if (!fileOperations.rename(path, destination)) {
            showNotice("重命名失败", "同名元素已存在，或文件当前不可写。")
            return
        }

        destination = Global.normalizeElementPath(destination)
        if (Global.normalizeElementPath(Global.get_filePath()) === Global.normalizeElementPath(path))
            Global.set_file("*", name)
        SignalBus.elementFilesMoved([{ "oldPath": path, "newPath": destination }])
    }

    function requestRenameDirectory(directoryPath) {
        var path = Global.normalizeElementPath(directoryPath)
        var parentDirectory = path.substring(0, path.lastIndexOf("/"))
        var name = path.substring(path.lastIndexOf("/") + 1)
        var validate = function(value) {
            var error = Global.fileEntryNameError(value)
            if (error.length || value.trim() === name)
                return error
            var destination = parentDirectory + "/" + value.trim()
            return fileOperations.exists(destination) || fileOperations.isDirectory(destination)
                    ? "此名称已存在，请使用其它名称。" : ""
        }
        pendingOperation = true
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupTextInput,
            "properties": {
                "title": "重命名文件夹",
                "content": "请输入新的文件夹名称",
                "value": name,
                "hintText": "所在目录：" + parentDirectory,
                "confirmText": "重命名",
                "validateValue": validate,
                "submitValue": function(value) {
                    var error = validate(value)
                    return error.length ? error : root.renameDirectory(path, value.trim())
                }
            },
            "callback": function() { root.finishOperation() }
        })
    }

    function renameDirectory(path, name) {
        var error = Global.fileEntryNameError(name)
        if (error.length)
            return error
        var source = Global.normalizeElementPath(path)
        var destination = source.substring(0, source.lastIndexOf("/") + 1) + name.trim()
        if (destination === source)
            return ""
        var containedFiles = fileOperations.filesInDirectory(source)
        if (!fileOperations.isDirectory(source) || !fileOperations.rename(source, destination))
            return "重命名失败，名称可能已存在，或目录当前不可写。"

        var activePath = Global.normalizeElementPath(Global.get_filePath())
        if (activePath.indexOf(source + "/") === 0) {
            var element = Global.parseElementPath(destination + activePath.substring(source.length))
            if (element) {
                Global.set_file(element.folder, element.name)
                // Reopen the editor's ElementIO at the new path before further edits.
                SignalBus.sendToMain("switched_file", {})
            }
        }
        clipboardPaths = clipboardPaths.map(function(entry) {
            var normalized = Global.normalizeElementPath(entry)
            return normalized.indexOf(source + "/") === 0
                    ? destination + normalized.substring(source.length) : entry
        })
        var moved = containedFiles.map(function(entry) {
            var oldPath = Global.normalizeElementPath(entry)
            return { "oldPath": oldPath, "newPath": destination + oldPath.substring(source.length) }
        })
        if (moved.length)
            SignalBus.elementFilesMoved(moved)
        fileSwitched()
        return ""
    }

    function requestDelete(paths) {
        var targets = (paths || selectedPaths).slice()
        if (!targets.length)
            return
        pendingOperation = true
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupNotice,
            "properties": {
                "title": targets.length > 1 ? "删除多个元素" : "删除元素",
                "content": targets.length > 1
                           ? "确定删除选中的 " + targets.length + " 个元素吗？此操作无法撤销。"
                           : "确定删除“" + Global.parseElementPath(targets[0]).name + "”吗？此操作无法撤销。",
                "doubleButton": true
            },
            "callback": function(result) {
                if (result === 1)
                    root.deleteFiles(targets)
                root.finishOperation()
            }
        })
    }

    function requestDeleteDirectory(directoryPath) {
        var path = Global.normalizeElementPath(directoryPath)
        var directoryName = path.substring(path.lastIndexOf("/") + 1)
        pendingOperation = true
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupNotice,
            "properties": {
                "title": "删除目录",
                "content": "确定删除目录“" + directoryName
                           + "”及其中的全部内容吗？此操作无法撤销。",
                "doubleButton": true
            },
            "callback": function(result) {
                if (result === 1)
                    root.deleteDirectory(path)
                root.finishOperation()
            }
        })
    }

    function deleteDirectory(directoryPath) {
        var path = Global.normalizeElementPath(directoryPath)
        var containedFiles = fileOperations.filesInDirectory(path)
        if (!fileOperations.removeDirectory(path)) {
            showNotice("删除失败", "无法删除所选目录。")
            return
        }

        if (containedFiles.length)
            SignalBus.elementFilesDeleted(containedFiles)
        var activePath = Global.normalizeElementPath(Global.get_filePath())
        if (activePath.indexOf(path + "/") === 0) {
            Global.set_file("*", "")
            fileSwitched()
        }
    }

    function deleteFiles(paths) {
        var deleted = []
        var activeDeleted = false
        var activePath = Global.normalizeElementPath(Global.get_filePath())
        for (var i = 0; i < paths.length; ++i) {
            if (!fileOperations.remove_file(paths[i]))
                continue
            var normalized = Global.normalizeElementPath(paths[i])
            deleted.push(normalized)
            activeDeleted = activeDeleted || normalized === activePath
        }
        if (deleted.length)
            SignalBus.elementFilesDeleted(deleted)
        if (activeDeleted) {
            Global.set_file("*", "")
            fileSwitched()
        }
        if (deleted.length !== paths.length)
            showNotice("删除未完全成功", (paths.length - deleted.length) + " 个元素无法删除。")
    }

    function moveEntriesToDirectory(paths, directory) {
        var moved = []
        var failed = 0
        var didMove = false
        var activePath = Global.normalizeElementPath(Global.get_filePath())
        for (var i = 0; i < paths.length; ++i) {
            var source = Global.normalizeElementPath(paths[i])
            var sourceIsDirectory = fileOperations.isDirectory(source)
            var containedFiles = sourceIsDirectory ? fileOperations.filesInDirectory(source) : []
            var destination = Global.normalizeElementPath(
                        fileOperations.moveToDirectory(source, directory))
            if (!destination.length) {
                ++failed
                continue
            }
            if (destination === source)
                continue

            didMove = true
            if (sourceIsDirectory) {
                for (var j = 0; j < containedFiles.length; ++j) {
                    var oldPath = Global.normalizeElementPath(containedFiles[j])
                    moved.push({ "oldPath": oldPath,
                                   "newPath": destination + oldPath.substring(source.length) })
                }
            } else {
                moved.push({ "oldPath": source, "newPath": destination })
            }

            if (activePath === source || (sourceIsDirectory
                                          && activePath.indexOf(source + "/") === 0)) {
                var newActivePath = sourceIsDirectory
                                    ? destination + activePath.substring(source.length)
                                    : destination
                var activeElement = Global.parseElementPath(newActivePath)
                if (activeElement)
                    Global.set_file(activeElement.folder, activeElement.name)
            }
        }
        if (moved.length) {
            SignalBus.elementFilesMoved(moved)
            fileSwitched()
        }
        if (didMove && !moved.length)
            fileSwitched()
        if (failed)
            showNotice("移动未完全成功", failed + " 个元素无法移动。")
        finishOperation()
    }

    function relayEntry(text, key, paths) {
        var snapshot = paths.slice()
        return {
            "text": text,
            "action": function() {
                SignalBus.elementsAddToRelayRequested(snapshot, key)
                root.finishOperation()
            }
        }
    }

    function relayGroupItems(paths) {
        var state = Global.elementRelayState(Global.project_location)
        var items = [relayEntry("最近", "recent", paths),
                     relayEntry("收藏", "favorites", paths)]
        for (var i = 0; i < state.groups.length; ++i)
            items.push(relayEntry(state.groups[i].name, "custom:" + state.groups[i].id, paths))
        return items
    }

    function contextMenuItems(paths) {
        var targets = paths.slice()
        var single = targets.length === 1
        var items = [
            { "text": "复制", "action": function() { root.copySelection(targets) } },
            { "text": "粘贴", "enabled": clipboardPaths.length > 0,
              "action": function() { root.pasteFiles(root.currentDirectory) } }
        ]
        if (single) {
            items.push({ "text": "克隆", "action": function() { root.cloneFile(targets[0]) } })
            items.push({ "text": "重命名…", "action": function() { root.requestRename(targets[0]) } })
        }
        items.push({ "text": "删除", "shortcutKey": Qt.Key_Delete,
                     "action": function() { root.requestDelete(targets) } })
        items.push({ "separator": true })
        items.push({ "text": "添加到中转区", "children": relayGroupItems(targets) })
        if (single) {
            items.push({ "separator": true })
            items.push({ "text": "在资源管理器中打开",
                         "action": function() {
                             fileOperations.revealInFileManager(targets[0])
                             root.finishOperation()
                         } })
        }
        return items
    }

    function directoryContextMenuItems(directoryPath) {
        var path = Global.normalizeElementPath(directoryPath)
        return [
            { "text": "打开", "action": function() { root.enterDirectory(path) } },
            { "text": "粘贴", "enabled": clipboardPaths.length > 0,
              "action": function() { root.pasteFiles(path) } },
            { "text": "重命名…", "shortcutKey": Qt.Key_F2,
              "action": function() { root.requestRenameDirectory(path) } },
            { "text": "删除", "shortcutKey": Qt.Key_Delete,
              "action": function() { root.requestDeleteDirectory(path) } },
            { "separator": true },
            { "text": "在资源管理器中浏览此目录",
              "action": function() {
                  fileOperations.revealInFileManager(path)
                  root.finishOperation()
              } }
        ]
    }

    function blankContextMenuItems() {
        return [
            { "text": "粘贴", "enabled": clipboardPaths.length > 0,
              "action": function() { root.pasteFiles(root.currentDirectory) } },
            { "separator": true },
            { "text": "在资源管理器中浏览此目录",
              "action": function() {
                  fileOperations.revealInFileManager(root.currentDirectory)
                  root.finishOperation()
              } }
        ]
    }

    function showContextMenu(target, x, y, path, index) {
        beginOperation()
        if (!isSelected(path))
            selectOnly(path, index)
        contextMenuActive = true
        SignalBus.contextMenuRequested(target, x, y, contextMenuItems(selectedPaths), null)
    }

    function showDirectoryContextMenu(target, x, y, directoryPath) {
        selectDirectory(directoryPath)
        contextMenuActive = true
        SignalBus.contextMenuRequested(target, x, y,
                                       directoryContextMenuItems(directoryPath), null)
    }

    function showBlankContextMenu(target, x, y) {
        beginOperation()
        clearSelection()
        contextMenuActive = true
        SignalBus.contextMenuRequested(target, x, y, blankContextMenuItems(), null)
    }

    function showNotice(title, content) {
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupNotice,
            "properties": { "title": title, "content": content }
        })
    }

    onFilePathChanged: {
        if (folderFileModel && folderDirectoryModel)
            resetFolderModels()
        finishOperation()
    }

    function resetFolderModels() {
        // A model retains watchers for visited folders on Windows. Release the
        // old models so those handles cannot prevent renaming a parent folder.
        if (folderFileModel)
            folderFileModel.destroy()
        if (folderDirectoryModel)
            folderDirectoryModel.destroy()
        folderFileModel = fileModelFactory.createObject(root)
        folderDirectoryModel = directoryModelFactory.createObject(root)
    }
    Component.onCompleted: resetFolderModels()

    Keys.onPressed: function(event) {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
            createEntryRequested(!!(event.modifiers & Qt.ShiftModifier))
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
            selectAll()
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
            var copyTargets = shortcutFileTargets()
            if (copyTargets.length)
                copySelection(copyTargets)
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            if (clipboardPaths.length)
                pasteFiles(selectedDirectoryPath.length
                           ? selectedDirectoryPath : currentDirectory)
            event.accepted = true
        } else if (event.key === Qt.Key_Delete) {
            if (selectedDirectoryPath.length)
                requestDeleteDirectory(selectedDirectoryPath)
            else
                requestDelete(shortcutFileTargets())
            event.accepted = true
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                   && selectedDirectoryPath.length) {
            enterDirectory(selectedDirectoryPath)
            event.accepted = true
        } else if (event.key === Qt.Key_F2) {
            if (selectedDirectoryPath.length) {
                requestRenameDirectory(selectedDirectoryPath)
            } else {
                var renameTargets = shortcutFileTargets()
                if (renameTargets.length === 1)
                    requestRename(renameTargets[0])
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            finishOperation()
            event.accepted = true
        }
    }

    Component {
        id: fileModelFactory
        FolderListModel {
            folder: Qt.resolvedUrl(root.filePath)
            showDirs: false
            showFiles: true
            showHidden: false
            nameFilters: ["*.xcse" + Global.current_element]
        }
    }

    Component {
        id: directoryModelFactory
        FolderListModel {
            folder: Qt.resolvedUrl(root.filePath)
            showDirs: true
            showFiles: false
            showHidden: false
        }
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.rightMargin: scrollBar.visible ? scrollBar.width : 0
        clip: true
        contentWidth: width
        contentHeight: directoryList.height + fileList.height

        DropArea {
            width: flickable.width
            height: Math.max(flickable.height, flickable.contentHeight)
            keys: ["xcshop-element-paths"]

            onEntered: function(drag) { drag.accepted = true }
            onDropped: function(drop) {
                if (SignalBus.draggedElementPaths.length)
                    root.moveEntriesToDirectory(SignalBus.draggedElementPaths.slice(),
                                                root.currentDirectory)
                drop.acceptProposedAction()
            }
        }

        MouseArea {
            id: backgroundPointer
            width: flickable.width
            height: Math.max(flickable.height, flickable.contentHeight)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                root.forceActiveFocus()
                if (mouse.button === Qt.RightButton)
                    root.showBlankContextMenu(backgroundPointer, mouse.x, mouse.y)
                else
                    root.finishOperation()
            }
        }

        ListView {
            id: directoryList
            width: parent.width
            height: contentHeight
            interactive: false
            model: folderDirectoryModel

            delegate: FileButton {
                id: directoryDelegate
                required property var model
                readonly property string directoryPath: root.currentDirectory + "/" + model.fileName
                width: directoryList.width
                height: 26
                text: model.fileName
                icon: "File_light"
                acceptsElementDrop: true
                operationSelected: root.selectedDirectoryPath === directoryPath
                operationMode: root.operationMode
                draggable: true
                dragPaths: [directoryPath]

                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        root.enterDirectory(directoryPath)
                }
                onContextMenuRequested: function(mouse) {
                    root.showDirectoryContextMenu(directoryDelegate, mouse.x, mouse.y,
                                                  directoryPath)
                }
                onPathsDropped: function(paths) {
                    root.moveEntriesToDirectory(paths, directoryPath)
                }
            }
        }

        ListView {
            id: fileList
            y: directoryList.height
            width: parent.width
            height: contentHeight
            interactive: false
            model: folderFileModel

            delegate: FileButton {
                id: fileDelegate
                required property var model
                readonly property string elementPath: root.pathForFileName(model.fileName)
                width: fileList.width
                height: 26
                text: model.fileBaseName
                icon: Global.current_element
                opened: root.isOpened(elementPath)
                operationSelected: root.isSelected(elementPath)
                operationMode: root.operationMode
                draggable: true
                dragPaths: operationSelected ? root.selectedPaths : [elementPath]

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        root.prepareFileDrag(elementPath, model.index, mouse.modifiers)
                }
                onClicked: function(mouse) {
                    root.handleFileClick(elementPath, model.index, mouse.modifiers)
                }
                onContextMenuRequested: function(mouse) {
                    root.showContextMenu(fileDelegate, mouse.x, mouse.y, elementPath, model.index)
                }
            }
        }
    }

    ScrollBar {
        id: scrollBar
        height: parent.height
        content_height: flickable.contentHeight
        animatePosition: false
        onHeight_outputChanged: if (visible) flickable.contentY = height_output
    }

    Connections {
        target: flickable
        function onContentYChanged() {
            if (scrollBar.visible)
                scrollBar.setContentOffset(flickable.contentY)
        }
    }

    Connections {
        target: SignalBus
        function onContextMenuClosed() {
            if (root.contextMenuActive && !root.pendingOperation)
                root.finishOperation()
        }
    }
}
