pragma ComponentBehavior: Bound
import QtQuick
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
    SettingsSection { title: "构建器"
        anchors.fill: parent

        SettingsCard {
            title: "构建器程序"
            contentHeight: form.height
            Column {
                id: form
                width: parent.width
                spacing: 12
                XCTextField {
                    id: pathField
                    width: parent.width
                    text: Builder.executablePath
                    placeholderText: "选择构建器程序"
                    enabled: !Builder.running && !Builder.queryingVersion
                }
                Flow {
                    width: parent.width
                    spacing: 8
                    SettingsActionButton { text: "浏览…"; enabled: !Builder.running && !Builder.queryingVersion; onClicked: executableDialog.openXC(false, "builder") }
                    SettingsActionButton {
                        text: "应用路径"; height: 32; radius: 6; textSize: 12; enabled: !Builder.running && !Builder.queryingVersion
                        primary: true
                        onClicked: {
                            Builder.executablePath = pathField.text
                            Builder.recheckExecutable()
                            root.feedback = Global.saveSettings() ? "" : "保存失败"
                            Builder.fetchVersion()
                        }
                    }
                    SettingsActionButton {
                        text: "恢复默认路径"; height: 32; radius: 6; textSize: 12; enabled: !Builder.running && !Builder.queryingVersion
                        onClicked: {
                            pathField.text = Builder.defaultExecutablePath
                            Builder.executablePath = pathField.text
                            root.feedback = Global.saveSettings() ? "" : "保存失败"
                            Builder.fetchVersion()
                        }
                    }
                    SettingsActionButton { text: "定位程序"; onClicked: file.revealInFileManager(Builder.executablePath) }
                }
                XCText {
                    width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
                    visible: Builder.running || (!Builder.available && !Builder.versionInfo.length)
                    xcText: Builder.running ? "构建中" : "构建器不可用"
                    textColor: Builder.available ? Colors.banned : Colors.error
                }
                XCText { width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false; visible: root.feedback.length > 0; xcText: root.feedback; textColor: Colors.error }
                XCText { xcText: "构建器信息"; onCenter: false; xcFontSize: 13 }
                XCText {
                    objectName: "builderVersionInfo"
                    width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
                    textFormat: Text.PlainText
                    visible: Builder.queryingVersion || Builder.versionInfo.length > 0
                    xcText: Builder.queryingVersion ? "获取中…" : Builder.displayVersionInfo
                    textColor: Builder.queryingVersion || Builder.versionValid ? Colors.banned : Colors.error
                }
            }
        }
        SettingsCard {
            title: "启动参数"
            contentHeight: argumentsField.height
            XCTextField {
                id: argumentsField
                objectName: "builderStartupArguments"
                width: parent.width
                text: Builder.startupArguments
                placeholderText: "可选"
                enabled: !Builder.running
                onTextEdited: {
                    Builder.startupArguments = text
                    root.feedback = Global.saveSettings() ? "" : "保存失败"
                }
            }
        }
    }
}
