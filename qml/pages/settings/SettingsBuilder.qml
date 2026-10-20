pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

Item {
    id: root
    property string feedback: ""
    XCFile { id: file }
    XCFileDialog {
        id: executableDialog
        nameFilters: ["构建器 (*.exe)", "所有文件 (*)"]
        onAccepted: pathField.text = BuildKits.localPath(selectedFile.toString())
    }
    Controls.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        Column {
            width: parent.width
            spacing: 16
            SettingsPageHeader { title: "构建器"; width: parent.width }
            SettingsCard {
                title: "构建器程序"
                description: "构建器独立运行。编辑器向它传入项目目录和构建套件目录，并接收日志、错误与警告。"
                contentHeight: form.height
                Column {
                    id: form
                    width: parent.width
                    spacing: 12
                    XCTextField {
                        id: pathField
                        width: parent.width
                        text: Builder.executablePath
                        placeholderText: "选择 xcshop-builder.exe"
                        enabled: !Builder.running
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        SettingsActionButton { text: "浏览…"; enabled: !Builder.running; onClicked: executableDialog.openXC(false, "builder") }
                        SettingsActionButton {
                            text: "应用路径"; height: 32; radius: 6; textSize: 12; enabled: !Builder.running
                            onClicked: {
                                Builder.executablePath = pathField.text
                                Builder.recheckExecutable()
                                root.feedback = Global.saveSettings() ? "路径已保存" : "保存设置失败，请检查写入权限"
                            }
                        }
                        SettingsActionButton {
                            text: "使用测试 Debug 路径"; height: 32; radius: 6; textSize: 12; enabled: !Builder.running
                            onClicked: {
                                pathField.text = Builder.defaultExecutablePath
                                Builder.executablePath = pathField.text
                                root.feedback = Global.saveSettings() ? "已恢复测试路径" : "保存设置失败"
                            }
                        }
                        SettingsActionButton { text: "定位程序"; onClicked: file.revealInFileManager(Builder.executablePath) }
                    }
                    XCText {
                        width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
                        xcText: Builder.running ? "正在构建，结束前不能切换程序路径。"
                                                : (Builder.available ? "已找到可执行文件（实际协议在构建时验证）" : "构建器不可用，请检查程序路径。")
                        textColor: Builder.available ? Colors.banned : Colors.error
                    }
                    XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; xcText: root.feedback }
                }
            }
            SettingsCard {
                title: "运行约定"
                description: "使用 --project 与 --kits 参数，要求 xcshop-builder/result 版本 2。项目的 generatePath 是数据包父目录，实际输出为 generatePath/项目名称。"
                contentHeight: 44
                XCText {
                    width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
                    xcText: "构建状态由应用统一保存，切换工作区不会丢失日志。取消构建会停止进程；取消后请重新构建确认输出。"
                    textColor: Colors.banned
                }
            }
        }
    }
}
