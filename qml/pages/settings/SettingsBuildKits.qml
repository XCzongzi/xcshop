pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
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
            var path = BuildKits.localPath(selectedFolder.toString())
            if (dialogID === "import") {
                var error = BuildKits.importKit(path)
                root.feedback = error.length ? error : "套件已导入，相同内容的已有文件已复用。"
            } else pathField.text = path
        }
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
    Controls.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        Column {
            width: parent.width
            spacing: 16
            SettingsPageHeader { title: "构建套件"; width: parent.width }
            SettingsCard {
                title: "本地构建套件"
                description: "模板决定如何组合蓝图与材料包。按模板 ID 识别，不受文件重命名影响；创建项目直接读取这里的模板。"
                contentHeight: pathForm.height
                Column {
                    id: pathForm
                    width: parent.width
                    spacing: 12
                    XCTextField { id: pathField; width: parent.width; text: BuildKits.kitsPath; enabled: !BuildKits.busy; placeholderText: "kits 根目录（内含 templates）" }
                    Flow {
                        width: parent.width
                        spacing: 8
                        SettingsActionButton { text: "浏览…"; enabled: !BuildKits.busy; onClicked: folderDialog.openXC("root", BuildKits.kitsPath) }
                        SettingsActionButton {
                            text: "应用目录"; height: 32; radius: 6; textSize: 12; enabled: !BuildKits.busy
                            primary: true
                            onClicked: {
                                BuildKits.kitsPath = pathField.text
                                BuildKits.refresh()
                                root.feedback = Global.saveSettings() ? "套件目录已保存" : "保存设置失败"
                            }
                        }
                        SettingsActionButton { text: "重新扫描"; enabled: !BuildKits.busy; onClicked: BuildKits.refresh() }
                        SettingsActionButton { text: "打开目录"; onClicked: file.revealInFileManager(BuildKits.kitsPath) }
                        SettingsActionButton { text: "导入套件…"; primary: true; enabled: !BuildKits.busy; onClicked: folderDialog.openXC("import", BuildKits.kitsPath) }
                        SettingsActionButton {
                            text: "恢复默认目录"; enabled: !BuildKits.busy
                            onClicked: { BuildKits.kitsPath = BuildKits.defaultKitsPath; pathField.text = BuildKits.kitsPath; Global.saveSettings() }
                        }
                    }
                    XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.banned; xcText: "导入时选择另一个 kits 根目录；模板、蓝图和材料一并导入，同名不同内容不会覆盖。当前编辑器数据版本：" + BuildKits.dataVersion }
                    XCText { width: parent.width; visible: root.feedback.length > 0; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; xcText: root.feedback }
                    XCText { width: parent.width; visible: BuildKits.issues.length > 0; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; textColor: Colors.error; xcText: BuildKits.issues.join("\n\n") }
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
                    XCText { visible: BuildKits.templates.length === 0; width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; xcText: "尚无本地模板，请选择套件目录或导入本地套件。" }
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
            SettingsCard {
                title: "在线获取"
                description: "在线模板仓库正在调整。此处保留在线目录、版本与下载入口，暂不请求旧仓库，也不修改本地套件。"
                contentHeight: 38
                SettingsActionButton { text: "在线模板目录（尚未接入）"; enabled: false }
            }
        }
    }
}
