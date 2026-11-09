pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PopupFrame {
    id: root
    dialogWidth: 650
    dialogHeight: 422

    title: "项目设置"
    property var projectData: ({})
    property string projectLocation: ""
    property var templateOptions: []
    property string validationMessage: ""
    property var pendingChanges: null
    readonly property var selectedTemplate: BuildKits.findTemplate(templateChoice.value)
    readonly property var versionOptions: Global.templateVersionOptions(selectedTemplate)

    function fieldValue(key, fallback) {
        if (!projectData || projectData[key] === undefined || projectData[key] === null)
            return fallback
        return String(projectData[key])
    }

    function syncFields() {
        nameField.text = fieldValue("name", "")
        namespaceField.text = fieldValue("namespace", "")
        outputField.text = fieldValue("generatePath", "")
        templateChoice.value = fieldValue("templateId", "").toLowerCase()
        versionChoice.value = fieldValue("version", "")
        validationMessage = ""
    }

    onAboutToOpen: {
        GameVersions.reload()
        syncFields()
        Qt.callLater(function() { nameField.forceActiveFocus() })
    }

    function submit() {
        if (versionWarning.visible || closing) return
        var name = nameField.text.trim()
        var namespaceName = namespaceField.text.trim()
        var outputPath = outputField.text.trim()

        if (!name.length || /[\\/:*?"<>|]/.test(name) || /[. ]$/.test(name)) {
            validationMessage = "项目名称格式不正确"
            return
        }
        if (!/^[a-z0-9_.-]+$/.test(namespaceName) || namespaceName === "." || namespaceName === "..") {
            validationMessage = "命名空间只能包含小写字母、数字、下划线、点和连字符，且不能是 . 或 .."
            return
        }
        var version = versionChoice.value
        if (!templateChoice.value.length || !selectedTemplate.valid
                || !versionOptions.some(function(option) { return option.id === version })) {
            validationMessage = "请选择构建模板和目标版本"
            return
        }
        if (selectedTemplate.dataVersion !== projectData.dataVersion) {
            validationMessage = "模板与项目数据版本不匹配，不能仅通过改写版本号迁移项目"
            return
        }
        if (!outputPath.length) {
            validationMessage = "请选择数据包生成位置"
            return
        }

        var packVersion = projectData.dataPackVersion
        if (version !== fieldValue("version", "") || !packVersion) {
            var mapping = BuildKits.resolveDataPackVersion(version)
            if (!mapping.valid) {
                validationMessage = mapping.error
                return
            }
            packVersion = { "major": mapping.major, "minor": mapping.minor }
        }
        var changes = {
            "name": name,
            "namespace": namespaceName,
            "generatePath": outputPath,
            "templateId": templateChoice.value,
            "version": version,
            "dataPackVersion": packVersion
        }
        var selectionChanged = version !== fieldValue("version", "")
                || templateChoice.value !== fieldValue("templateId", "").toLowerCase()
        if (selectionChanged && versionOptions.some(function(option) { return option.id === version && option.extended })) {
            pendingChanges = changes
            versionWarning.open()
            return
        }
        close(changes)
    }

    Keys.onEscapePressed: close(null)

    PopupNotice {
        id: versionWarning
        objectName: "projectVersionWarning"
        parent: root
        anchors.fill: parent
        z: 2
        visible: false
        manageVisibility: true
        title: "版本兼容性提示"
        content: "该版本并未明确受到模板的支持，因此生成的数据包在该版本可能无法正常工作。但也未被证实必然会失效。\n是否确认接着更改？"
        doubleButton: true
        onClosed: function(result) {
            var changes = root.pendingChanges
            root.pendingChanges = null
            if (result === 1 && changes)
                root.close(changes)
            else
                root.forceActiveFocus()
        }
    }

    XCFolderDialog {
        id: outputDialog
        onAccepted: outputField.text = BuildKits.localPath(selectedFolder.toString())
    }

    Grid {
        id: formGrid
        x: 24
        y: 82
        width: parent.width - 48
        columns: 2
        columnSpacing: 12
        rowSpacing: 15

        FormField {
            label: "项目名称"
            XCTextField {
                id: nameField
                anchors.fill: parent
                placeholderText: "项目名称"
                onTextEdited: root.validationMessage = ""
                onAccepted: namespaceField.forceActiveFocus()
            }
        }

        FormField {
            label: "命名空间"
            XCTextField {
                id: namespaceField
                anchors.fill: parent
                placeholderText: "例如：myshop"
                onTextEdited: root.validationMessage = ""
            }
        }

        FormField {
            label: "构建模板"
            XCComboBox {
                id: templateChoice
                objectName: "projectTemplateChoice"
                anchors.fill: parent
                options: root.templateOptions
                onValueActivated: function(value) {
                    templateChoice.value = value
                    var versions = root.selectedTemplate.versions || []
                    versionChoice.value = versions.length ? versions[versions.length - 1] : ""
                    root.validationMessage = ""
                }
            }
        }

        FormField {
            label: "目标版本"
            XCComboBox {
                id: versionChoice
                objectName: "projectVersionChoice"
                anchors.fill: parent
                options: root.versionOptions.map(function(option) { return { value: option.id, label: option.id } })
                onValueActivated: function(value) { versionChoice.value = value; root.validationMessage = "" }
            }
        }
    }

    XCText {
        id: outputLabel
        x: 24
        y: 239
        xcText: "数据包生成父目录（文件夹名称可在总览的构建栏设置）"
        xcFontSize: 11
        boldFont: false
        onCenter: false
        textColor: Colors.changeA(Colors.text, 0.72)
    }

    XCTextField {
        id: outputField
        x: 24
        y: 260
        width: parent.width - 126
        height: 36
        placeholderText: "选择生成目录"
        onTextEdited: root.validationMessage = ""
        onAccepted: root.submit()
    }

    TextButton {
        x: outputField.x + outputField.width + 8
        y: outputField.y
        height: outputField.height
        text: "浏览"
        radius: 7
        textSize: 12
        widthBorderSize: 10
        buttonColor: Colors.changeA(Colors.pressed, 0.82)
        onClicked: outputDialog.openXC("output", outputField.text.length
                                      ? outputField.text : root.projectLocation)
    }

    XCText {
        x: 24
        y: 309
        width: parent.width - 48
        xcText: root.validationMessage
        visible: root.validationMessage.length > 0
        onCenter: false
        xcFontSize: 12
        boldFont: false
        textColor: Colors.error
    }

    component FormField: Item {
        property alias label: fieldLabel.xcText
        default property alias content: fieldHost.data
        width: (formGrid.width - formGrid.columnSpacing) / 2
        height: 56

        XCText {
            id: fieldLabel
            width: parent.width
            xcFontSize: 11
            boldFont: false
            onCenter: false
            textColor: Colors.changeA(Colors.text, 0.72)
        }
        Item {
            id: fieldHost
            y: 20
            width: parent.width
            height: 36
        }
    }
    actions: [
        ActionButton {
            text: "取消"
            onClicked: root.close(null)
        },
        ActionButton {
            primary: true

            text: "保存"
            onClicked: root.submit()
        }
    ]
}
