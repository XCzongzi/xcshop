pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PopupFrame {
    id: root
    dialogWidth: 650
    dialogHeight: root.selectedTemplate.allowsNewer ? 452 : 422

    title: "项目设置"
    property var projectData: ({})
    property string projectLocation: ""
    property var templateOptions: []
    property string validationMessage: ""
    readonly property var selectedTemplate: BuildKits.findTemplate(templateChoice.value)

    function fieldValue(key, fallback) {
        if (!projectData || projectData[key] === undefined || projectData[key] === null)
            return fallback
        return String(projectData[key])
    }

    function versionsForTemplate(templateValue) {
        for (var i = 0; i < templateOptions.length; ++i) {
            if (String(templateOptions[i].value) === String(templateValue)) {
                var versions = templateOptions[i].versions || []
                var values = []
                for (var j = 0; j < versions.length; ++j)
                    values.push({ "value": String(versions[j]), "label": String(versions[j]) })
                var current = fieldValue("version", "")
                if (String(templateValue).toLowerCase() === fieldValue("templateId", "").toLowerCase()
                        && versions.indexOf(current) < 0 && BuildKits.versionSupport(templateValue, current) >= 0)
                    values.push({ "value": current, "label": current + "（未明确支持）" })
                return values
            }
        }
        var current = fieldValue("version", "")
        return current.length ? [{ "value": current, "label": current }] : []
    }

    function syncFields() {
        nameField.text = fieldValue("name", "")
        namespaceField.text = fieldValue("namespace", "")
        outputField.text = fieldValue("generatePath", "")
        templateChoice.value = fieldValue("templateId", "").toLowerCase()
        versionChoice.options = versionsForTemplate(templateChoice.value)
        versionChoice.value = fieldValue("version", "")
        customVersion.text = ""
        validationMessage = ""
    }

    onAboutToOpen: {
        syncFields()
        Qt.callLater(function() { nameField.forceActiveFocus() })
    }

    function submit() {
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
        var version = selectedTemplate.allowsNewer && customVersion.text.trim().length
                ? customVersion.text.trim() : versionChoice.value
        if (!templateChoice.value.length || !version.length || !selectedTemplate.valid) {
            validationMessage = "请选择构建模板和目标版本"
            return
        }
        if (selectedTemplate.dataVersion !== projectData.dataVersion) {
            validationMessage = "模板与项目数据版本不匹配，不能仅通过改写版本号迁移项目"
            return
        }
        if (BuildKits.versionSupport(templateChoice.value, version) < 0) {
            validationMessage = "该模板不支持输入的目标版本"
            return
        }
        if (!outputPath.length) {
            validationMessage = "请选择数据包生成位置"
            return
        }

        close({
            "name": name,
            "namespace": namespaceName,
            "generatePath": outputPath,
            "templateId": templateChoice.value,
            "version": version
        })
    }

    Keys.onEscapePressed: close(null)

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
                    versionChoice.options = root.versionsForTemplate(value)
                    versionChoice.value = versionChoice.options.length
                            ? String(versionChoice.options[0].value) : ""
                    customVersion.text = ""
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
                onValueActivated: function(value) { versionChoice.value = value; customVersion.text = ""; root.validationMessage = "" }
            }
        }
    }

    XCTextField {
        id: customVersion
        x: 24; y: 219; width: parent.width - 48; height: 32
        visible: !!root.selectedTemplate.allowsNewer
        placeholderText: "可选：输入模板允许尝试的较新版本（构建器将提示兼容性警告）"
        onTextEdited: root.validationMessage = ""
    }

    XCText {
        id: outputLabel
        x: 24
        y: root.selectedTemplate.allowsNewer ? 269 : 239
        xcText: "数据包生成父目录（文件夹名称可在总览的构建栏设置）"
        xcFontSize: 11
        boldFont: false
        onCenter: false
        textColor: Colors.changeA(Colors.text, 0.72)
    }

    XCTextField {
        id: outputField
        x: 24
        y: root.selectedTemplate.allowsNewer ? 290 : 260
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
        y: root.selectedTemplate.allowsNewer ? 339 : 309
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
