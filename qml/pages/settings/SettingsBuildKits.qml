pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    property string selectedPath: ""
    property string feedback: ""
    readonly property var selectedTemplate: {
        var entries = BuildKits.templates
        for (var i = 0; i < entries.length; ++i)
            if (entries[i].path === selectedPath) return entries[i]
        return ({})
    }
    XCFile { id: file }
    function selectAvailableTemplate() {
        var preferred = BuildKits.findTemplate(BuildKits.preferredTemplateId)
        selectedPath = preferred.path || (BuildKits.templates.length ? BuildKits.templates[0].path : "")
    }
    Component.onCompleted: { BuildKits.refresh(); selectAvailableTemplate() }
    Connections {
        target: BuildKits
        function onCatalogChanged() { if (!root.selectedTemplate.path) root.selectAvailableTemplate() }
    }
    XCFolderDialog {
        id: folderDialog
        onAccepted: {
            root.feedback = ""
            BuildKits.acquire(selectedFolder.toString())
        }
    }
    XCFileDialog {
        id: zipDialog
        title: "导入构建套件"
        nameFilters: ["构建套件压缩包 (*.zip)"]
        onAccepted: { root.feedback = ""; BuildKits.acquire(selectedFile.toString()) }
    }
    function confirmRemoval() {
        var template = selectedTemplate
        SignalBus.sendToMain("Popup.show", {
            "component": Constants.popupNotice,
            "properties": {
                "title": "移除模板",
                "content": "将“" + template.name + "”的模板文件移入回收站？\n引用它的项目不会被修改，蓝图和材料包会保留，避免破坏其他模板。",
                "doubleButton": true
            },
            "callback": function(result) {
                if (result !== 1) return
                var error = BuildKits.removeTemplate(template.id)
                root.feedback = error.length ? error : "模板已移入回收站，可从回收站恢复。"
                Global.saveSettings()
            }
        })
    }
    SettingsSection { title: "构建套件"
        anchors.fill: parent

        SettingsCard {
            title: "获取套件"
            description: "下载完整套件包并导入当前目录，也可导入本地 ZIP 或 kits 文件夹。同名同内容自动复用，不同内容会提示冲突。"
            contentHeight: acquisitionColumn.height
            Column {
                id: acquisitionColumn
                width: parent.width
                spacing: 12
                Flow {
                    width: parent.width
                    spacing: 8
                    SettingsActionButton {
                        objectName: "downloadBuildKits"
                        text: BuildKits.downloadCooldownSeconds > 0
                              ? "下载并导入（" + BuildKits.downloadCooldownSeconds + " 秒）" : "下载并导入"
                        primary: true
                        enabled: !BuildKits.busy && BuildKits.downloadCooldownSeconds === 0
                        onClicked: { root.feedback = ""; BuildKits.acquire() }
                    }
                    SettingsActionButton { text: "导入 ZIP…"; enabled: !BuildKits.busy; onClicked: zipDialog.openXC(false, "kits") }
                    SettingsActionButton { text: "导入文件夹…"; enabled: !BuildKits.busy; onClicked: folderDialog.openXC("import", BuildKits.kitsPath) }
                    SettingsActionButton { text: "取消"; visible: BuildKits.acquiring; onClicked: BuildKits.cancelAcquisition() }
                }
                Rectangle {
                    width: parent.width; height: 3; radius: 1.5
                    visible: BuildKits.acquiring
                    color: Colors.background_n
                    Rectangle {
                        width: parent.width * (BuildKits.acquisitionProgress < 0 ? 0.15 : BuildKits.acquisitionProgress / 100)
                        height: parent.height; radius: parent.radius; color: Colors.themeColor
                        SequentialAnimation on opacity {
                            running: BuildKits.acquiring && BuildKits.acquisitionProgress < 0
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.3; to: 1; duration: 600 }
                            NumberAnimation { from: 1; to: 0.3; duration: 600 }
                        }
                    }
                }
                XCText {
                    width: parent.width; visible: BuildKits.acquisitionStatus.length > 0
                    onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
                    xcText: BuildKits.acquisitionStatus
                }
            }
        }
        SettingsCard {
            title: "模板 · " + BuildKits.templates.length
            description: "查看模板介绍、支持版本与依赖。数据版本不兼容或依赖缺失的模板不能用于创建项目。"
            contentHeight: catalogColumn.height
            Column {
                id: catalogColumn
                width: parent.width
                spacing: 12
                XCText { width: parent.width; visible: root.feedback.length > 0; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; xcText: root.feedback }
                XCText { width: parent.width; visible: BuildKits.issues.length > 0; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.error; xcText: BuildKits.issues.join("\n\n") }
                XCText { visible: BuildKits.templates.length === 0; width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; xcText: "尚无本地模板，请在上方下载或导入套件。" }
                Repeater {
                    model: BuildKits.templates
                    delegate: TextButton {
                        required property var modelData
                        width: catalogColumn.width
                        height: 40
                        text: modelData.name + "  ·  " + (modelData.versions || []).join(", ")
                              + (modelData.allowsNewer ? " …" : "")
                              + (!modelData.valid ? "  [无效]" : modelData.dataVersion !== BuildKits.dataVersion ? "  [数据版本不兼容]" : "")
                              + (modelData.id === BuildKits.preferredTemplateId ? "  [新项目默认]" : "")
                        textSize: 12; radius: 7; widthBorderSize: 10
                        btnSelected: root.selectedPath === modelData.path
                        allowSelectedClick: true
                        onClicked: root.selectedPath = modelData.path
                    }
                }
                Column {
                    width: parent.width
                    spacing: 10
                    visible: !!root.selectedTemplate.path
                    XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; xcText: "ID：" + (root.selectedTemplate.id || "") + "\n数据版本：" + root.selectedTemplate.dataVersion + "\n文件：" + (root.selectedTemplate.path || "") }
                    XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; xcText: (root.selectedTemplate.introduction || []).join("\n\n") || "暂无介绍" }
                    XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned; xcText: "蓝图：" + (root.selectedTemplate.blueprintPath || "无效引用") + "\n材料包：" + (root.selectedTemplate.materialsPath || "无效引用") + "\n材料 / 列表文件：" + (root.selectedTemplate.materialCount || 0) }
                    Flow {
                        width: parent.width; spacing: 8
                        SettingsActionButton {
                            text: "设为新项目默认"; height: 30; radius: 6; textSize: 12
                            primary: true
                            enabled: !!root.selectedTemplate.valid && BuildKits.identityValid && root.selectedTemplate.dataVersion === BuildKits.dataVersion
                            onClicked: { BuildKits.preferredTemplateId = root.selectedTemplate.id; Global.saveSettings() }
                        }
                        SettingsActionButton { text: "定位模板"; onClicked: file.revealInFileManager(root.selectedTemplate.path) }
                        SettingsActionButton { text: "定位蓝图"; enabled: !!root.selectedTemplate.blueprintPath; onClicked: file.revealInFileManager(root.selectedTemplate.blueprintPath) }
                        SettingsActionButton { text: "打开材料包"; enabled: !!root.selectedTemplate.materialsPath; onClicked: file.revealInFileManager(root.selectedTemplate.materialsPath) }
                        SettingsActionButton { text: "移除模板"; enabled: !BuildKits.busy && BuildKits.identityValid; onClicked: root.confirmRemoval() }
                    }
                }
            }
        }
    }
}
