pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true
    readonly property bool compactLayout: height < 560 || width < 900

    XCFile { id: projectFile }

    XCFolderDialog {
        id: projectFolderDialog
        onAccepted: {
            var selectedPath = Qt.url(selectedFolder).toLocaleString().replace("file:///", "")
            root.openProject(selectedPath)
        }
    }

    function showOpenError(message) {
        pageEvent("NoticeBar.show", ["无法打开项目", message])
    }

    function openProject(path) {
        var projectPath = path.replace(/\\/g, "/").replace(/\/+$/, "")
        var raw = projectFile.read(projectPath + "/xcshop.json")
        var projectInfo
        try {
            projectInfo = JSON.parse(raw)
        } catch (error) {
            showOpenError("所选文件夹中没有有效的 xcshop.json。请选择 XCShop 项目的根目录。")
            return
        }

        if (!projectInfo || !projectInfo.name || !projectInfo.namespace) {
            showOpenError("项目配置不完整，无法识别为有效的 XCShop 项目。")
            return
        }

        Global.project_location = projectPath
        Global.current_element = "Total"
        Global.rememberProject(projectPath, projectInfo)
        pageEvent("Start.", { "object": "projectOpened" })
    }

    function showRecentProjectContextMenu(target, x, y, projectPath) {
        SignalBus.contextMenuRequested(target, x, y, [
            { "text": "删除记录", "action": function() {
                Global.removeRecentProject(projectPath)
            } },
            { "separator": true },
            { "text": "在资源管理器中打开", "action": function() {
                projectFile.revealInFileManager(projectPath)
            } }
        ], null)
    }

    component RecentProjectRow: Rectangle {
        id: recentEntry
        required property var model
        property bool hovered: false
        property bool pressed: false

        width: parent ? parent.width : 0
        height: 58
        radius: 12
        color: hovered ? Colors.changeA(Colors.pressed, 0.86) : Colors.changeA(Colors.background, 0.24)
        border.width: 1
        border.color: hovered ? Colors.changeA(Colors.border, 0.42) : Colors.changeA(Colors.text, 0.07)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        scale: pressed ? 0.98 : 1.0
        XCText {
            x: 16
            y: 10
            width: parent.width - x - 16
            xcText: recentEntry.model.name
            onCenter: false
            xcFontSize: 13
        }
        XCText {
            x: 16
            y: 31
            width: parent.width - x - 16
            xcText: recentEntry.model.version + "  ·  " + recentEntry.model.path
            onCenter: false
            xcFontSize: 10
            boldFont: false
            textColor: Colors.banned
            elide: Text.ElideRight
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: recentEntry.hovered = true
            onExited: { recentEntry.hovered = false; recentEntry.pressed = false }
            onPressed: function(mouse) {
                if (mouse.button === Qt.LeftButton)
                    recentEntry.pressed = true
            }
            onReleased: recentEntry.pressed = false
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.showRecentProjectContextMenu(recentEntry, mouse.x, mouse.y,
                                                      recentEntry.model.path)
                    return
                }
                root.openProject(recentEntry.model.path)
            }
        }
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        color: Global.backgroundMode === "color" ? Colors.background : Colors.transparent
        clip: true

        Rectangle {
            visible: Global.backgroundMode === "color"
            width: Math.max(parent.width, parent.height) * 0.72
            height: width
            x: parent.width * 0.44
            y: -height * 0.57
            radius: width / 2
            color: Colors.changeA(Colors.border, 0.075)
            layer.enabled: true
            layer.effect: GaussianBlur {
                radius: 56
                samples: 63
                transparentBorder: true
            }
        }
        Rectangle {
            visible: Global.backgroundMode === "color"
            width: 420
            height: 420
            x: -210
            y: parent.height - 230
            radius: width / 2
            color: Colors.changeA(Colors.border, 0.045)
            layer.enabled: true
            layer.effect: GaussianBlur {
                radius: 48
                samples: 63
                transparentBorder: true
            }
        }

        Item {
            id: pageContent
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 56, 1120)

            Row {
                id: topBar
                x: -pageContent.x
                y: 12
                width: parent.width
                height: 64 + Constants.titleBarHeight

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 13

                    Rectangle {
                        width: 46
                        height: 46
                        radius: 14
                        color: Colors.changeA(Colors.foreground, 0.80)
                        border.width: 1
                        border.color: Colors.changeA(Colors.border, 0.48)
                        Image {
                            anchors.centerIn: parent
                            width: 31
                            height: 31
                            source: "qrc:/assets/gui/png/logo.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        XCText { xcText: "Minecraft xcshop"; onCenter: false; xcFontSize: 22 }
                        XCText {
                            xcText: "UI商店生成器"
                            onCenter: false
                            xcFontSize: 11
                            boldFont: false
                            textColor: Colors.banned
                        }
                    }
                }

            }

            Item {
                id: layoutArea
                anchors.top: topBar.bottom
                anchors.topMargin: root.compactLayout ? 20 : 36
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                Row {
                    id: layoutRow
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    spacing: 28

                Item {
                    id: welcomeColumn
                    width: Math.min(600, Math.max(390, layoutRow.width * 0.53))
                    height: parent.height

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: 13

                        XCText { xcText: "商店项目"; onCenter: false; xcFontSize: 34 }

                        Row {
                            id: actionRow
                            width: parent.width
                            spacing: 14
                            LargeIconButton {
                                title: "创建"
                                subtitle: "新的xcshop项目"
                                icon: "qrc:/assets/gui/controls/new_project.png"
                                layout_width: actionRow.width
                                layout_amount: 2
                                minimumScale: root.compactLayout ? 0.88 : 1.0
                                onClicked: root.pageEvent("Start.", { "object": "create" })
                            }
                            LargeIconButton {
                                title: "打开"
                                subtitle: "已有xcshop项目"
                                icon: "qrc:/assets/gui/controls/open_project.png"
                                layout_width: actionRow.width
                                layout_amount: 2
                                minimumScale: root.compactLayout ? 0.88 : 1.0
                                onClicked: projectFolderDialog.openXC("project",
                                                                      Global.recentProjects.length
                                                                      ? Global.recentProjects[0].path : APP_DIRPATH)
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 54
                            radius: 13
                            color: Colors.changeA(Colors.foreground, 0.45)
                            border.width: 1
                            border.color: Colors.changeA(Colors.text, 0.08)
                            XCText {
                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                xcText: "更多"
                                onCenter: false
                                xcFontSize: 12
                                textColor: Colors.banned
                            }
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 62
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                IconButton {
                                    height: 34
                                    text: "关于"
                                    icon: "qrc:/assets/gui/controls/about.png"
                                    onClicked: root.pageEvent("Start.", { "object": "about" })
                                }
                                IconButton {
                                    height: 34
                                    text: "设置"
                                    icon: "qrc:/assets/gui/controls/settings.png"
                                    onClicked: root.pageEvent("Start.", { "object": "settings" })
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: recentPanel
                    width: Math.max(270, layoutRow.width - welcomeColumn.width - layoutRow.spacing)
                    height: Math.min(root.compactLayout ? 330 : 440,
                                     Math.max(root.compactLayout ? 250 : 300, parent.height - 16))
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 20
                    color: Colors.changeA(Colors.foreground, 0.70)
                    // border.width: 1
                    // border.color: Colors.changeA(Colors.text, 0.10)

                    layer.enabled: true
                    // 卡片使用半透明前景色；默认阴影会从背后透出，在浅色
                    // 主题中使整个面板发暗。保留轻微投影即可。
                    layer.effect: XCShadow {
                        shadowColor: Colors.changeA(Colors.shadow, 0.20)
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 20
                        spacing: 4
                        XCText { xcText: "最近项目"; onCenter: false; xcFontSize: 19 }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 56
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        height: 1
                        color: Colors.changeA(Colors.text, 0.09)
                    }

                    Item {
                        visible: Global.recentProjects.length === 0
                        anchors.centerIn: parent
                        width: parent.width - 50
                        height: 96
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 50
                            height: 50
                            radius: 16
                            color: Colors.changeA(Colors.border, 0.14)
                            XCText { anchors.centerIn: parent; xcText: "+"; xcFontSize: 28; boldFont: false; textColor: Colors.border }
                        }
                        XCText {
                            anchors.top: parent.top
                            anchors.topMargin: 66
                            width: parent.width
                            xcText: "还没有最近项目"
                            onCenter: true
                            xcFontSize: 14
                        }
                    }

                    ListView {
                        id: recentList
                        visible: Global.recentProjects.length > 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        anchors.topMargin: 72
                        anchors.bottomMargin: 20
                        clip: true
                        spacing: 8
                        model: Global.recentProjects
                        delegate: RecentProjectRow { }
                    }
                }
                }
            }
        }
    }
}
