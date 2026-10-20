pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    anchors.fill: parent
    focus: true

    property string title: "项目设置"
    property var projectData: ({})
    property string projectLocation: ""
    property var templateOptions: []
    property string validationMessage: ""
    property var result: null
    readonly property var selectedTemplate: BuildKits.findTemplate(templateChoice.currentValue)

    signal closed(var result)

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
        templateChoice.currentValue = fieldValue("templateId", "").toLowerCase()
        versionChoice.options = versionsForTemplate(templateChoice.currentValue)
        versionChoice.currentValue = fieldValue("version", "")
        customVersion.text = ""
        validationMessage = ""
    }

    function open() {
        scrim.opacity = 0
        dialog.opacity = 0
        dialog.scale = 0.97
        syncFields()
        openAnimation.restart()
        Qt.callLater(function() { nameField.forceActiveFocus() })
    }

    function close(closeResult) {
        if (closeAnimation.running)
            return
        result = closeResult === undefined ? null : closeResult
        closeAnimation.restart()
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
                ? customVersion.text.trim() : versionChoice.currentValue
        if (!templateChoice.currentValue.length || !version.length || !selectedTemplate.valid) {
            validationMessage = "请选择构建模板和目标版本"
            return
        }
        if (selectedTemplate.dataVersion !== projectData.dataVersion) {
            validationMessage = "模板与项目数据版本不匹配，不能仅通过改写版本号迁移项目"
            return
        }
        if (BuildKits.versionSupport(templateChoice.currentValue, version) < 0) {
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
            "templateId": templateChoice.currentValue,
            "version": version
        })
    }

    Keys.onEscapePressed: close(null)

    XCFolderDialog {
        id: outputDialog
        onAccepted: outputField.text = BuildKits.localPath(selectedFolder.toString())
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        MouseArea { anchors.fill: parent; hoverEnabled: true }
    }

    Rectangle {
        id: dialog
        width: Math.min(650, Math.max(420, root.width - 48))
        height: root.selectedTemplate.allowsNewer ? 452 : 422
        anchors.centerIn: parent
        radius: 15
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.985)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.12)
        transformOrigin: Item.Center
        opacity: 0

        layer.enabled: true
        layer.effect: XCShadow {
            shadowColor: "#a8000000"
            shadowBlur: 0.85
            shadowVerticalOffset: 10
        }

        Rectangle { width: parent.width; height: 5; radius: 15; color: Colors.border }

        XCText {
            x: 24
            y: 25
            width: parent.width - 48
            xcText: root.title
            onCenter: false
            xcFontSize: 21
        }

        Rectangle {
            x: 24
            y: 65
            width: parent.width - 48
            height: 1
            color: Colors.changeA(Colors.text, 0.10)
        }

        Grid {
            id: formGrid
            x: 24
            y: 82
            width: parent.width - 48
            columns: 2
            columnSpacing: 12
            rowSpacing: 15

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
                GlobalChoiceBox {
                    id: templateChoice
                    anchors.fill: parent
                    options: root.templateOptions
                    onValueActivated: function(value) {
                        versionChoice.options = root.versionsForTemplate(value)
                        versionChoice.currentValue = versionChoice.options.length
                                ? String(versionChoice.options[0].value) : ""
                        customVersion.text = ""
                        root.validationMessage = ""
                    }
                }
            }

            FormField {
                label: "目标版本"
                GlobalChoiceBox {
                    id: versionChoice
                    anchors.fill: parent
                    onValueActivated: { customVersion.text = ""; root.validationMessage = "" }
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
            xcText: "数据包生成父目录（最终输出为此目录 / 项目名称）"
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

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 8

            TextButton {
                text: "取消"
                height: 34
                radius: 7
                textSize: 13
                widthBorderSize: 12
                buttonColor: Colors.changeA(Colors.pressed, 0.82)
                onClicked: root.close(null)
            }
            TextButton {
                text: "保存"
                height: 34
                radius: 7
                textSize: 13
                widthBorderSize: 13
                buttonColor: Colors.changeA(Colors.border, 0.72)
                firedColor: Colors.changeA(Colors.border, 0.88)
                pressedColor: Colors.border
                textColor: "#1b1b1b"
                onClicked: root.submit()
            }
        }
    }

    ParallelAnimation {
        id: openAnimation
        PropertyAnimation { target: scrim; property: "opacity"; to: 0.42; duration: 180 / Global.animationSpeed; easing.type: Easing.OutCubic }
        PropertyAnimation { target: dialog; property: "opacity"; to: 1; duration: 180 / Global.animationSpeed; easing.type: Easing.OutCubic }
        PropertyAnimation { target: dialog; property: "scale"; to: 1; duration: 220 / Global.animationSpeed; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: closeAnimation
        PropertyAnimation { target: scrim; property: "opacity"; to: 0; duration: 150 / Global.animationSpeed; easing.type: Easing.InCubic }
        PropertyAnimation { target: dialog; property: "opacity"; to: 0; duration: 130 / Global.animationSpeed; easing.type: Easing.InCubic }
        PropertyAnimation { target: dialog; property: "scale"; to: 0.97; duration: 150 / Global.animationSpeed; easing.type: Easing.InCubic }
        onFinished: root.closed(root.result)
    }
}
