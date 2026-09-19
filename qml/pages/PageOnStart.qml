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
        height: 54
        radius: 11
        color: hovered ? Colors.changeA(Colors.pressed, 0.72)
                       : Colors.changeA(Colors.background_n, 0.16)
        border.width: 1
        border.color: hovered ? Colors.changeA(Colors.border, 0.50)
                              : Colors.changeA(Colors.text, 0.06)

        Behavior on color { ColorAnimation { duration: 120 / Global.animationSpeed } }
        Behavior on border.color { ColorAnimation { duration: 120 / Global.animationSpeed } }
        Behavior on scale { NumberAnimation { duration: 90 / Global.animationSpeed; easing.type: Easing.OutCubic } }
        scale: pressed ? 0.985 : 1.0

        XCText {
            x: 14
            y: 7
            width: parent.width - x - 14
            xcText: recentEntry.model.name
            onCenter: false
            xcFontSize: 12
        }
        XCText {
            x: 14
            y: 29
            width: parent.width - x - 14
            xcText: recentEntry.model.version + "  ·  " + recentEntry.model.path
            onCenter: false
            xcFontSize: 9
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
        color: Global.backgroundMode === "color" ? Colors.background_n : Colors.transparent
        clip: true

        Item {
            id: recentPanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: Math.max(300, Math.min(440, parent.width * 0.38))

            Rectangle {
                id: recentPanelFill
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                color: Colors.transparent
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Colors.changeA(Colors.foreground,
                                              Global.backgroundMode === "color" ? 0.94 : 0.97)
                    }
                    GradientStop {
                        position: 1.0
                        color: Colors.changeA(Colors.foreground,
                                              Global.backgroundMode === "color" ? 0.76 : 0.88)
                    }
                }
            }

            Item {
                id: panelTransitionSource
                x: parent.width
                width: 48
                height: parent.height
                visible: false

                Rectangle {
                    width: 26
                    height: parent.height
                    color: Colors.transparent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Colors.changeA(Colors.foreground,
                                                  Global.backgroundMode === "color" ? 0.76 : 0.88)
                        }
                        GradientStop {
                            position: 0.36
                            color: Colors.changeA(Colors.foreground,
                                                  Global.backgroundMode === "color" ? 0.42 : 0.52)
                        }
                        GradientStop {
                            position: 1.0
                            color: Colors.changeA(Colors.foreground, 0.0)
                        }
                    }
                }
            }

            GaussianBlur {
                anchors.fill: panelTransitionSource
                source: panelTransitionSource
                radius: 10
                samples: 21
                transparentBorder: false
            }

            Item {
                id: recentHeading
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Constants.titleBarHeight + (root.compactLayout ? 28 : 48)
                anchors.leftMargin: root.compactLayout ? 16 : 24
                anchors.rightMargin: root.compactLayout ? 24 : 32
                height: 31

                Rectangle {
                    x: 0
                    y: 4
                    width: 3
                    height: 23
                    radius: 2
                    color: Colors.border
                }

                XCText {
                    x: 14
                    xcText: "最近项目"
                    onCenter: false
                    xcFontSize: 22
                }
            }

            Rectangle {
                visible: Global.recentProjects.length === 0
                anchors.left: recentHeading.left
                anchors.right: recentHeading.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 12
                height: 96
                radius: 12
                color: Colors.changeA(Colors.background_n, 0.13)
                border.width: 1
                border.color: Colors.changeA(Colors.text, 0.06)

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    XCText {
                        width: parent.width
                        xcText: "还没有最近项目"
                        onCenter: false
                        xcFontSize: 14
                    }
                    XCText {
                        width: parent.width
                        xcText: "创建或打开项目后，它会显示在这里。"
                        onCenter: false
                        xcFontSize: 10
                        boldFont: false
                        textColor: Colors.banned
                    }
                }
            }

            ListView {
                id: recentList
                visible: Global.recentProjects.length > 0
                anchors.top: recentHeading.bottom
                anchors.bottom: parent.bottom
                anchors.left: recentHeading.left
                anchors.right: recentHeading.right
                anchors.topMargin: 18
                anchors.bottomMargin: root.compactLayout ? 18 : 24
                clip: true
                spacing: 7
                model: Global.recentProjects
                delegate: RecentProjectRow { }
            }
        }

        Item {
            id: mainPanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: recentPanel.right
            anchors.right: parent.right

            Item {
                id: mainContent
                anchors.left: parent.left
                anchors.leftMargin: root.compactLayout ? 40 : 64
                anchors.top: parent.top
                anchors.topMargin: Constants.titleBarHeight + (root.compactLayout ? 24 : 44)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.compactLayout ? 24 : 40
                width: Math.min(600, parent.width - anchors.leftMargin - 32)

                Column {
                    id: brandGroup
                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: parent.width
                    spacing: 2

                    XCText {
                        xcText: "Minecraft xcshop"
                        onCenter: false
                        xcFontSize: root.compactLayout ? 27 : 32
                    }
                    XCText {
                        anchors.left: parent.left
                        xcText: "UI商店生成器"
                        onCenter: false
                        xcFontSize: 12
                        boldFont: false
                        textColor: Colors.banned
                    }
                }

                Column {
                    id: projectGroup
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 12

                    XCText {
                        xcText: "商店项目"
                        onCenter: false
                        xcFontSize: 18
                    }

                    Row {
                        id: actionRow
                        width: parent.width
                        height: 140 * (root.compactLayout ? 0.88 : 1.0)
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
                }

                Rectangle {
                    id: morePanel
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
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
    }
}
