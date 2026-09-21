pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import "qrc:/assets/js/request.js" as XHR

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true
    content_height: creationContent.height + 32

    property string projectNameValue: ""
    property string namespaceValue: ""
    property string storagePathValue: ""
    property string generatePathValue: ""
    property var templates: ({})
    readonly property var templateItems: templates && templates.Intros ? templates.Intros : []
    property int currentTemplate: -1
    property string currentVersion: ""
    property string templateIntroduction: ""
    property bool templatesLoading: false
    property string templateStatus: ""
    property double controlsOpacity: 1
    property real visualContentOffset: height_output
    property bool projectCreationSucceeded: false
    // Set by PageOnStart when this page is hosted in its right-side panel.
    property var embeddedBackAction: null

    readonly property bool projectNameGood: projectNameValue.trim().length > 0
                                             && !/[\\\\/:*?"<>|]/.test(projectNameValue)
                                             && !/[. ]$/.test(projectNameValue)
    readonly property bool namespaceGood: /^[a-z0-9_]+$/.test(namespaceValue)
    readonly property bool canCreate: projectNameGood
                                      && namespaceGood
                                      && storagePathValue.trim().length > 0
                                      && generatePathValue.trim().length > 0
                                      && currentTemplate >= 0
                                      && currentVersion.length > 0

    Behavior on visualContentOffset {
        NumberAnimation { duration: 160 / Global.animationSpeed; easing.type: Easing.OutCubic }
    }

    component CreationCard: Rectangle {
        // Keep sections distinct without making them look raised above the page.
        radius: 9
        color: Colors.changeA(Colors.foreground,
                              Global.backgroundMode === "color" ? 0.38 : 0.44)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.08)
    }

    Component.onCompleted: {
        input_storagePath.setContext(APP_DIRPATH + "/projects")
        input_generatePath.setContext(DESKTOP_DIRPATH)
        setTemplate()
    }

    function setTemplate() {
        var raw = xcFile.read("templates.json")
        try {
            var loaded = JSON.parse(raw)
            templates = loaded && loaded.Intros ? loaded : ({})
            templateStatus = templateItems.length ? "已加载 " + templateItems.length + " 个模板" : "未找到可用模板"
        } catch (error) {
            templates = ({})
            templateStatus = "模板列表暂不可用，可点击“更新模板”重新获取"
        }
        currentTemplate = -1
        currentVersion = ""
        templateIntroduction = ""
    }

    function selectTemplate(index) {
        currentTemplate = index
        currentVersion = ""
        templateIntroduction = "暂无介绍"

        try {
            var detail = JSON.parse(xcFile.read("templates/" + index + ".json"))
            if (detail && detail.Intro)
                templateIntroduction = detail.Intro
        } catch (error) {
        }
    }

    function updateTemplates() {
        if (templatesLoading)
            return
        templatesLoading = true
        templateStatus = "正在获取模板列表…"
        XHR.sendRequest(Constants.url_templates, function(response) {
            try {
                xcFile.write("templates.json", response.content)
                root.setTemplate()
            } catch (error) {
                root.templateStatus = "更新失败，请检查网络后重试"
            }
            root.templatesLoading = false
        })
    }

    function refreshIntroduction() {
        if (currentTemplate < 0 || templatesLoading)
            return
        templatesLoading = true
        templateIntroduction = "正在获取模板介绍…"
        XHR.sendRequest(Constants.url_templatesPer + currentTemplate + ".json", function(response) {
            try {
                xcFile.write("templates/" + root.currentTemplate + ".json", response.content)
                var detail = JSON.parse(response.content)
                root.templateIntroduction = detail && detail.Intro ? detail.Intro : "暂无介绍。"
            } catch (error) {
                root.templateIntroduction = "获取介绍失败，请稍后重试。"
            }
            root.templatesLoading = false
        })
    }

    function showProjectResult(title, content) {
        pageEvent("Popup.show", {
            "component": Constants.popupNotice,
            "properties": {
                "title": title,
                "content": content
            },
            "callback": function(result) {
                root.executeFromMain("notice", result)
            }
        })
    }

    function goBack() {
        if (embeddedBackAction) {
            embeddedBackAction()
            return
        }
        pageEvent("Creating.back", {})
    }

    function createProject() {
        if (!canCreate)
            return

        projectCreationSucceeded = false
        var name = projectNameValue.trim()
        var location = storagePathValue.trim() + "/" + name
        var projectInfo = {
            "name": name,
            "namespace": namespaceValue.trim(),
            "generatePath": generatePathValue.trim(),
            "version": currentVersion,
            "template": currentTemplate
        }
        if (xcFile.folder(location)
                && xcFile.write(location + "/xcshop.json", JSON.stringify(projectInfo))
                && xcFile.folder(location + "/UI")
                && xcFile.folder(location + "/Item")
                && xcFile.folder(location + "/Cost")
                && xcFile.folder(location + "/Display")) {
            Global.project_location = location
            Global.rememberProject(location, projectInfo)
            projectCreationSucceeded = true
            showProjectResult("创建成功", "项目已成功创建至：\n" + Global.project_location
                                + "\n\n即将在工作区中打开项目")
        } else {
            showProjectResult("创建失败", "无法创建项目目录或写入配置文件，请检查路径权限后重试。")
        }
    }

    function executeFromMain(type) {
        if (type === "notice" && projectCreationSucceeded) {
            controlsOpacity = 0
            createdAnimation.start()
        }
    }

    NumberAnimation {
        id: createdAnimation
        target: root
        property: "x"
        to: -root.width
        duration: 650 / Global.animationSpeed
        easing.type: Easing.InOutCubic
        onFinished: root.pageEvent("Creating.projectCreated", {})
    }

    XCFile { id: xcFile }

    XCFolderDialog {
        id: folderDialog
        onAccepted: {
            var selectedPath = Qt.url(currentFolder).toLocaleString().replace("file:///", "")
            if (dialogID === "storage")
                input_storagePath.setContext(selectedPath)
            else if (dialogID === "generate")
                input_generatePath.setContext(selectedPath)
        }
    }

    Item {
        id: creationContent
        width: parent.width
        height: contentColumn.y + contentColumn.height + 42
        y: -root.visualContentOffset
        opacity: root.controlsOpacity

        Behavior on opacity { NumberAnimation { duration: 220 / Global.animationSpeed } }

        Column {
            id: contentColumn
            width: Math.min(940, parent.width - 64)
            anchors.horizontalCenter: parent.horizontalCenter
            y: 56
            spacing: 16

            XCText {
                xcText: "创建项目"
                onCenter: false
                xcFontSize: 22
            }

            CreationCard {
                id: baseCard
                width: parent.width
                height: baseForm.height + 40

                Column {
                    id: baseForm
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 12

                    XCText { xcText: "基础信息"; onCenter: false; xcFontSize: 18 }
                    Row {
                        width: parent.width
                        spacing: 16
                        XCKeyInput {
                            id: input_projectName
                            keyText: "项目名称"
                            fieldText: "例如：my_shop"
                            width: (parent.width - parent.spacing) / 2
                            onFieldContextChanged: root.projectNameValue = getContext()
                        }
                        XCKeyInput {
                            id: input_namespace
                            keyText: "命名空间"
                            fieldText: "例如：myshop"
                            width: (parent.width - parent.spacing) / 2
                            onFieldContextChanged: root.namespaceValue = getContext()
                        }
                    }
                    XCText {
                        visible: root.projectNameValue.length > 0 && !root.projectNameGood
                        xcText: "项目名称不能包含 \\ / : * ? \" < > |，且不能以空格或点结尾。"
                        onCenter: false
                        xcFontSize: 12
                        boldFont: false
                        textColor: Colors.error
                    }
                    XCText {
                        visible: root.namespaceValue.length > 0 && !root.namespaceGood
                        xcText: "命名空间格式不正确。"
                        onCenter: false
                        xcFontSize: 12
                        boldFont: false
                        textColor: Colors.error
                    }
                }
            }

            CreationCard {
                id: pathCard
                width: parent.width
                height: pathForm.height + 40

                Column {
                    id: pathForm
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 14

                    XCText { xcText: "相关路径"; onCenter: false; xcFontSize: 18 }
                    XCKeyInput {
                        id: input_storagePath
                        keyText: "项目存储位置"
                        fieldText: "选择项目文件夹"
                        width: parent.width
                        onFieldContextChanged: root.storagePathValue = getContext()
                        TextButton {
                            text: "浏览"
                            width: 52
                            height: 28
                            x: parent.width - width
                            y: parent.height - height - 2
                            radius: 6
                            textSize: 12
                            widthBorderSize: 4
                            buttonColor: Colors.changeA(Colors.pressed, 0.82)
                            onClicked: folderDialog.openXC("storage", parent.getContext())
                        }
                    }
                    XCKeyInput {
                        id: input_generatePath
                        keyText: "数据包生成位置"
                        fieldText: "选择生成目录"
                        width: parent.width
                        onFieldContextChanged: root.generatePathValue = getContext()
                        TextButton {
                            text: "浏览"
                            width: 52
                            height: 28
                            x: parent.width - width
                            y: parent.height - height - 2
                            radius: 6
                            textSize: 12
                            widthBorderSize: 4
                            buttonColor: Colors.changeA(Colors.pressed, 0.82)
                            onClicked: folderDialog.openXC("generate", parent.getContext())
                        }
                    }
                }
            }

            CreationCard {
                id: templateCard
                width: parent.width
                height: 318

                XCText { x: 20; y: 18; xcText: "生成模板"; onCenter: false; xcFontSize: 18 }
                XCText {
                    x: 20
                    y: 46
                    width: parent.width - 180
                    xcText: root.templateStatus
                    onCenter: false
                    xcFontSize: 12
                    boldFont: false
                    textColor: Colors.banned
                }
                TextButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    y: 16
                    text: root.templatesLoading ? "更新中…" : "更新模板"
                    enabled: !root.templatesLoading
                    height: 30
                    radius: 6
                    textSize: 12
                    widthBorderSize: 9
                    buttonColor: Colors.changeA(Colors.pressed, 0.85)
                    onClicked: root.updateTemplates()
                }

                Rectangle {
                    id: selectionArea
                    x: 20
                    y: 72
                    width: parent.width - 40
                    height: 226
                    radius: 9
                    color: Colors.changeA(Colors.background, 0.28)
                    border.width: 1
                    border.color: Colors.changeA(Colors.text, 0.07)

                    Row {
                        id: selectionRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        property real columnUnit: Math.max(0, (width - spacing * 4 - 2) / 4)

                        Column {
                            width: selectionRow.columnUnit
                            spacing: 8
                            XCText { xcText: "模板"; onCenter: false; xcFontSize: 13 }
                            ListView {
                                id: templateList
                                width: parent.width
                                height: 178
                                clip: true
                                spacing: 6
                                model: root.templateItems
                                delegate: TextButton {
                                    required property int index
                                    required property var model
                                    width: templateList.width
                                    height: 38
                                    radius: 7
                                    text: model.id
                                    textSize: 13
                                    widthBorderSize: 10
                                    buttonColor: Colors.changeA(Colors.background, 0.30)
                                    firedColor: Colors.changeA(Colors.pressed, 0.88)
                                    pressedColor: Colors.changeA(Colors.border, 0.72)
                                    btnSelected: root.currentTemplate === index
                                    onClicked: root.selectTemplate(index)
                                }
                            }
                        }

                        Rectangle { width: 1; height: parent.height; color: Colors.changeA(Colors.text, 0.09) }

                        Column {
                            width: selectionRow.columnUnit * 2
                            spacing: 8
                            Row {
                                width: parent.width
                                XCText { xcText: "模板介绍"; onCenter: false; xcFontSize: 13 }
                                Item { width: Math.max(0, parent.width - refreshButton.width - 50); height: 1 }
                                TextButton {
                                    id: refreshButton
                                    text: root.templatesLoading ? "获取中…" : "刷新介绍"
                                    enabled: root.currentTemplate >= 0 && !root.templatesLoading
                                    height: 24
                                    radius: 5
                                    textSize: 11
                                    widthBorderSize: 6
                                    buttonColor: Colors.changeA(Colors.pressed, 0.82)
                                    onClicked: root.refreshIntroduction()
                                }
                            }
                            XCText {
                                width: parent.width
                                height: 178
                                xcText: root.templateIntroduction
                                onCenter: false
                                xcWrapMode: true
                                xcFontSize: 12
                                boldFont: false
                                textColor: Colors.banned
                            }
                        }

                        Rectangle { width: 1; height: parent.height; color: Colors.changeA(Colors.text, 0.09) }

                        Column {
                            width: selectionRow.columnUnit
                            spacing: 8
                            XCText { xcText: "目标版本"; onCenter: false; xcFontSize: 13 }
                            ListView {
                                id: versionList
                                width: parent.width
                                height: 178
                                clip: true
                                spacing: 6
                                model: root.currentTemplate >= 0 && root.currentTemplate < root.templateItems.length
                                       ? root.templateItems[root.currentTemplate].versions : []
                                delegate: TextButton {
                                    required property int index
                                    required property var model
                                    width: versionList.width
                                    height: 38
                                    radius: 7
                                    text: model.modelData
                                    textSize: 13
                                    widthBorderSize: 10
                                    buttonColor: Colors.changeA(Colors.background, 0.30)
                                    firedColor: Colors.changeA(Colors.pressed, 0.88)
                                    pressedColor: Colors.changeA(Colors.border, 0.72)
                                    btnSelected: root.currentVersion === model.modelData
                                    onClicked: root.currentVersion = model.modelData
                                }
                            }
                        }
                    }
                }
            }

            CreationCard {
                width: parent.width
                height: 70

                XCText {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - actionRow.width - 52
                    xcText: root.canCreate ? "准备就绪，随时可以创建"
                                           : "请继续完成项目信息填写"
                    onCenter: false
                    xcFontSize: 12
                    boldFont: false
                    textColor: root.canCreate ? Colors.banned : Colors.changeA(Colors.text, 0.58)
                }
                Row {
                    id: actionRow
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    TextButton {
                        text: "取消"
                        height: 34
                        radius: 7
                        textSize: 13
                        widthBorderSize: 12
                        buttonColor: Colors.changeA(Colors.pressed, 0.82)
                        onClicked: root.goBack()
                    }
                    TextButton {
                        text: "创建项目"
                        enabled: root.canCreate
                        height: 34
                        radius: 7
                        textSize: 13
                        widthBorderSize: 12
                        buttonColor: Colors.changeA(Colors.border, 0.72)
                        firedColor: Colors.changeA(Colors.border, 0.90)
                        pressedColor: Colors.border
                        textColor: root.canCreate ? "#1b1b1b" : Colors.text
                        onClicked: root.createProject()
                    }
                }
            }
        }
    }

    TextButton {
        id: backButton
        z: 2
        x: 16
        y: 16
        text: "← 返回"
        height: 32
        radius: 6
        textSize: 13
        widthBorderSize: 10
        buttonColor: Colors.changeA(Colors.background, 0.70)
        firedColor: Colors.changeA(Colors.foreground, 0.92)
        opacity: root.controlsOpacity
        onClicked: root.goBack()
    }
}
