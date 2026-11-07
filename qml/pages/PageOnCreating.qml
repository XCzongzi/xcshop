pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true
    content_height: creationContent.height + 32

    property string projectNameValue: ""
    property string namespaceValue: ""
    property string storagePathValue: ""
    property string generatePathValue: ""
    readonly property var templateItems: BuildKits.identityValid ? BuildKits.templates.filter(function(t) {
        return t.valid && t.dataVersion === BuildKits.dataVersion
    }) : []
    property string currentTemplateId: ""
    property bool templateSelectionTouched: false
    readonly property int currentTemplate: templateItems.findIndex(function(t) { return t.id === root.currentTemplateId })
    readonly property var selectedTemplate: currentTemplate >= 0 ? templateItems[currentTemplate] : ({})
    property string currentVersion: ""
    readonly property string templateIntroduction: (selectedTemplate.introduction || []).join("\n\n")
    readonly property string templateStatus: templateItems.length ? "来自设置中的构建套件 · " + templateItems.length + " 个可用模板"
                                                                : "没有可用模板，请在设置 → 构建套件中配置或导入本地套件"
    property double controlsOpacity: 1
    property real visualContentOffset: height_output
    property bool projectCreationSucceeded: false
    // Set by PageOnStart when this page is hosted in its right-side panel.
    property var embeddedBackAction: null
    property Item backdropSource: Global.mainWindow_backdrop

    readonly property bool projectNameGood: projectNameValue.trim().length > 0
                                             && !/[\\\\/:*?"<>|]/.test(projectNameValue)
                                             && !/[. ]$/.test(projectNameValue)
                                             && projectNameValue.trim() !== "." && projectNameValue.trim() !== ".."
    readonly property bool namespaceGood: /^[a-z0-9_.-]+$/.test(namespaceValue)
                                         && namespaceValue !== "." && namespaceValue !== ".."
    readonly property bool canCreate: projectNameGood
                                      && namespaceGood
                                      && storagePathValue.trim().length > 0
                                      && generatePathValue.trim().length > 0
                                      && currentTemplate >= 0
                                      && currentVersion.length > 0
                                      && BuildKits.versionSupport(currentTemplateId, currentVersion) >= 0

    Behavior on visualContentOffset {
        NumberAnimation { duration: 160 / Global.animationSpeed; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: {
        input_storagePath.setContext(APP_DIRPATH + "/projects")
        input_generatePath.setContext(DESKTOP_DIRPATH)
        BuildKits.refresh()
        setTemplate()
    }

    function setTemplate() {
        var index = templateItems.findIndex(function(t) { return t.id === BuildKits.preferredTemplateId })
        if (index < 0 && templateItems.length) index = 0
        selectTemplate(index)
    }

    function selectTemplate(index) {
        currentTemplateId = index >= 0 && index < templateItems.length ? templateItems[index].id : ""
        var versions = selectedTemplate.versions || []
        currentVersion = versions.length ? versions[versions.length - 1] : ""
        customVersionField.text = ""
    }

    Connections {
        target: BuildKits
        function onPreferredTemplateIdChanged() { if (!root.templateSelectionTouched) root.setTemplate() }
        function onCatalogChanged() { if (root.currentTemplate < 0) root.setTemplate() }
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
        if (!canCreate || projectCreationSucceeded)
            return

        projectCreationSucceeded = false
        var name = projectNameValue.trim()
        var location = storagePathValue.trim() + "/" + name
        if (xcFile.isDirectory(location) || xcFile.exists(location)) {
            showProjectResult("创建失败", "目标位置已存在同名文件或目录，为避免覆盖原有数据，请更换项目名称或存储位置。")
            return
        }
        var projectInfo = {
            "name": name,
            "namespace": namespaceValue.trim(),
            "generatePath": generatePathValue.trim(),
            "version": currentVersion,
            "dataVersion": BuildKits.dataVersion,
            "templateId": currentTemplateId,
            "shops": []
        }
        if (xcFile.folder(location)
                && xcFile.folder(location + "/UI")
                && xcFile.folder(location + "/Item")
                && xcFile.folder(location + "/Cost")
                && xcFile.folder(location + "/Display")
                && xcFile.writeAtomic(location + "/xcshop.json", JSON.stringify(projectInfo, null, 2))) {
            Global.project_location = location
            Global.rememberProject(location, projectInfo)
            BuildKits.preferredTemplateId = currentTemplateId
            Global.saveSettings()
            projectCreationSucceeded = true
            Global.current_element = "Global"
            pageEvent("Creating.projectCreated", { "name": name })
        } else {
            showProjectResult("创建失败", "无法创建项目目录或写入配置文件，请检查路径权限后重试。")
        }
    }

    function executeFromMain(type) {
        // Failure notices leave the form available for correction.
    }

    XCFile { id: xcFile }

    XCFolderDialog {
        id: folderDialog
        onAccepted: {
            var selectedPath = BuildKits.localPath(selectedFolder.toString())
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

            ContentSurface {
                id: baseCard
                hoverEffectsEnabled: true
                backdropSource: root.backdropSource
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
                            fieldText: ""
                            width: (parent.width - parent.spacing) / 2
                            onFieldContextChanged: root.projectNameValue = getContext()
                        }
                        XCKeyInput {
                            id: input_namespace
                            keyText: "命名空间"
                            fieldText: ""
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

            ContentSurface {
                id: pathCard
                hoverEffectsEnabled: true
                backdropSource: root.backdropSource
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
                        keyText: "数据包生成父目录"
                        fieldText: "数据包将生成在此目录 / 项目名称下"
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

            ContentSurface {
                id: templateCard
                hoverEffectsEnabled: true
                backdropSource: root.backdropSource
                width: parent.width
                height: 318

                XCText { x: 20; y: 18; xcText: "生成模板"; onCenter: false; xcFontSize: 18 }
                XCText {
                    x: 20
                    y: 46
                    width: parent.width - 40
                    xcText: root.templateStatus
                    onCenter: false
                    xcFontSize: 12
                    boldFont: false
                    textColor: Colors.banned
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
                    border.color: Colors.changeA(Colors.outline, 0.07)

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
                                    text: root.templateItems[index].name
                                    textSize: 13
                                    widthBorderSize: 10
                                    buttonColor: Colors.changeA(Colors.background, 0.30)
                                    firedColor: Colors.changeA(Colors.pressed, 0.88)
                                    pressedColor: Colors.changeA(Colors.border, 0.72)
                                    btnSelected: root.currentTemplate === index
                                    onClicked: { root.templateSelectionTouched = true; root.selectTemplate(index) }
                                }
                            }
                        }

                        Rectangle { width: 1; height: parent.height; color: Colors.changeA(Colors.outline, 0.09) }

                        Column {
                            width: selectionRow.columnUnit * 2
                            spacing: 8
                            XCText { xcText: "模板介绍"; onCenter: false; xcFontSize: 13 }
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

                        Rectangle { width: 1; height: parent.height; color: Colors.changeA(Colors.outline, 0.09) }

                        Column {
                            width: selectionRow.columnUnit
                            spacing: 8
                            XCText { xcText: "目标版本"; onCenter: false; xcFontSize: 13 }
                            ListView {
                                id: versionList
                                width: parent.width
                                height: root.selectedTemplate.allowsNewer ? 132 : 178
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
                                    onClicked: { customVersionField.text = ""; root.currentVersion = model.modelData }
                                }
                            }
                            XCTextField {
                                id: customVersionField
                                visible: !!root.selectedTemplate.allowsNewer
                                width: parent.width
                                height: 32
                                placeholderText: "或输入较新版本"
                                onTextEdited: root.currentVersion = text.trim()
                            }
                        }
                    }
                }
            }

            ContentSurface {
                hoverEffectsEnabled: true
                backdropSource: root.backdropSource
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
                    ActionButton {
                        text: "取消"
                        onClicked: root.goBack()
                    }
                    ActionButton {
                        primary: true

                        text: "创建项目"
                        enabled: root.canCreate
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
        firedColor: Colors.changeA(Colors.card, 0.92)
        opacity: root.controlsOpacity
        onClicked: root.goBack()
    }
}
