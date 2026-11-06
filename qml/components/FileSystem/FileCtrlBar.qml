pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import xcshop
import "../../../js/WorkspaceSchema.js" as Schema

Item{
    id:root

    property bool hideBackBtn: false
    property string filePath: ""
    property bool creatingEntry: false

    signal backbtnClicked()
    signal elementPathsDropped(var paths)
    signal creationFinished()

    function requestCreate(isFolder) {
        if (creatingEntry)
            return
        creatingEntry = true
        var directory = Global.normalizeElementPath(filePath)
        var elementType = Global.current_element
        var project = Global.project_location
        var destinationFor = function(value) {
            return directory + "/" + value.trim() + (isFolder ? "" : ".xcse" + elementType)
        }
        var validate = function(value) {
            var error = Global.fileEntryNameError(value)
            if (error.length)
                return error
            var destination = destinationFor(value)
            return xcfile.exists(destination) || xcfile.isDirectory(destination)
                    ? "此名称已存在，请使用其它名称。" : ""
        }
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupTextInput,
            "properties": {
                "title": isFolder ? "新建文件夹" : "新建元素",
                "content": isFolder ? "为新文件夹输入名称" : "为新元素输入名称",
                "placeholderText": isFolder ? "文件夹名称" : "元素名称（无需扩展名）",
                "hintText": "创建位置：" + directory,
                "confirmText": "创建",
                "validateValue": validate,
                "submitValue": function(value) {
                    if (Global.project_location !== project || Global.current_element !== elementType)
                        return "工作区已切换，请取消后重新创建。"
                    var error = validate(value)
                    if (error.length)
                        return error
                    if (!xcfile.isDirectory(directory))
                        return "创建位置已不存在，请取消后重新选择目录。"
                    var destination = destinationFor(value)
                    var success = isFolder ? xcfile.folder(destination)
                                           : xcfile.writeAtomic(destination, root.defaultElementContent())
                    return success ? "" : "创建失败，请检查目录是否可写。"
                }
            },
            "callback": function(value) {
                root.creatingEntry = false
                root.creationFinished()
                if (!isFolder && typeof value === "string"
                        && Global.project_location === project && Global.current_element === elementType)
                    SignalBus.elementOpenRequested(destinationFor(value))
            }
        })
    }

    function defaultElementContent(){
        if (Global.current_element === "UI") {
            return JSON.stringify({
                "containerType": "",
                "customName": "",
                "openCommand": "",
                "placeholderItem": { "enabled": false, "element": "" },
                "slots": [],
                "nestedGroups": []
            })
        }
        if (Global.current_element === "Item") {
            return JSON.stringify(Schema.item())
        }
        if (Global.current_element === "Display") {
            return JSON.stringify(Schema.display())
        }
        if (Global.current_element === "Cost") {
            return JSON.stringify({
                "display": "",
                "itemSyntaxError": false,
                "type": { "kind": "experience_level", "value": "", "filter": false }
            })
        }
        return ""
    }

    TextButton{
        id: backButton
        visible:!root.hideBackBtn
        x:2
        y:13
        text:"◂返回上一级 "
        radius: 3
        buttonColor: backDropArea.containsDrag ? Colors.fired : Colors.transparent
        onClicked: root.backbtnClicked()
    }

    DropArea {
        id: backDropArea
        anchors.fill: backButton
        enabled: backButton.visible && SignalBus.draggedElementPaths.length > 0
        keys: ["xcshop-element-paths"]

        onEntered: function(drag) { drag.accepted = true }
        onDropped: function(drop) {
            root.elementPathsDropped(SignalBus.draggedElementPaths.slice())
            drop.acceptProposedAction()
        }
    }

    XCFile{
        id:xcfile
    }

    ImageButton {
        id: newFolderButton
        x:parent.width - width - 3
        y: 5
        btnSize: 24
        btnRadius: 3
        imageSource: "qrc:/assets/gui/element/Bar/newMenu_light.png"
        XCToolTip {
            active: newFolderButton.hovered
            text: "新建文件夹（管理器中 Ctrl+Shift+N）"
        }
        onClicked: root.requestCreate(true)
    }
    ImageButton {
        id: newElementButton
        x:parent.width - width*2 - 5
        y: 5
        btnSize: 24
        btnRadius: 3
        imageSource: "qrc:/assets/gui/element/Bar/newFile_light.png"
        XCToolTip {
            active: newElementButton.hovered
            text: "新建元素（管理器中 Ctrl+N）"
        }
        onClicked: root.requestCreate(false)
    }
    

}
