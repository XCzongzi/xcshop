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
        color: Colors.transparent
        clip: true

        // Compose real linear/radial gradients first, then soften the complete
        // result with a Gaussian blur.
        Item {
            id: backgroundGradientSource
            anchors.fill: parent
            visible: false
            property real flowPhase: 0

            NumberAnimation on flowPhase {
                from: 0
                to: Math.PI * 2
                duration: 18000 / Global.animationSpeed
                loops: Animation.Infinite
                easing.type: Easing.Linear
                running: root.visible
            }

            Rectangle {
                anchors.fill: parent
                color: Global.backgroundMode === "color"
                       ? Colors.background_n : Colors.transparent
            }

            LinearGradient {
                anchors.fill: parent
                start: Qt.point(width * (0.03 + 0.05 * Math.sin(backgroundGradientSource.flowPhase)),
                                height * (0.04 + 0.04 * Math.cos(backgroundGradientSource.flowPhase * 2)))
                end: Qt.point(width * (0.96 + 0.03 * Math.cos(backgroundGradientSource.flowPhase)),
                              height * (0.94 + 0.05 * Math.sin(backgroundGradientSource.flowPhase * 2)))
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Colors.changeA(Qt.darker(Colors.border, 1.35),
                                              Global.backgroundMode === "color" ? 0.34 : 0.20)
                    }
                    GradientStop {
                        position: 0.24
                        color: Colors.changeA(Colors.border,
                                              Global.backgroundMode === "color" ? 0.22 : 0.14)
                    }
                    GradientStop {
                        position: 0.52
                        color: Colors.changeA(Colors.background_n, 0.0)
                    }
                    GradientStop {
                        position: 0.78
                        color: Colors.changeA(Qt.lighter(Colors.foreground, 1.35),
                                              Global.backgroundMode === "color" ? 0.28 : 0.16)
                    }
                    GradientStop {
                        position: 1.0
                        color: Colors.changeA(Qt.lighter(Colors.border, 1.22),
                                              Global.backgroundMode === "color" ? 0.18 : 0.10)
                    }
                }
            }

            RadialGradient {
                anchors.fill: parent
                horizontalOffset: width * (0.24 + 0.10 * Math.sin(backgroundGradientSource.flowPhase))
                verticalOffset: height * (-0.20 + 0.08 * Math.cos(backgroundGradientSource.flowPhase * 2))
                horizontalRadius: width * (0.66 + 0.05 * Math.cos(backgroundGradientSource.flowPhase))
                verticalRadius: height * (0.82 + 0.05 * Math.sin(backgroundGradientSource.flowPhase))
                angle: -12 + 10 * Math.sin(backgroundGradientSource.flowPhase * 2)
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Colors.changeA(Qt.lighter(Colors.border, 1.45),
                                              Global.backgroundMode === "color" ? 0.30 : 0.18)
                    }
                    GradientStop {
                        position: 0.34
                        color: Colors.changeA(Colors.border,
                                              Global.backgroundMode === "color" ? 0.20 : 0.12)
                    }
                    GradientStop {
                        position: 0.68
                        color: Colors.changeA(Qt.lighter(Colors.foreground, 1.18),
                                              Global.backgroundMode === "color" ? 0.08 : 0.05)
                    }
                    GradientStop {
                        position: 1.0
                        color: Colors.transparent
                    }
                }
            }
        }

        GaussianBlur {
            anchors.fill: parent
            source: backgroundGradientSource
            radius: 16
            samples: 33
            transparentBorder: false
            // The source moves continuously, so caching would freeze the flow
            // or force an unnecessary extra texture update on every frame.
            cached: false
        }

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
                layer.enabled: true
                layer.effect: XCShadow {
                    shadowColor: Colors.changeA(Colors.shadow, 0.38)
                    shadowBlur: 0.32
                    shadowHorizontalOffset: 5
                    shadowVerticalOffset: 0
                }
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
                id: utilityPanel
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Constants.titleBarHeight + (root.compactLayout ? 12 : 20)
                anchors.leftMargin: root.compactLayout ? 16 : 24
                anchors.rightMargin: root.compactLayout ? 24 : 32
                height: 54

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconButton {
                        height: 34
                        text: "设置"
                        icon: "qrc:/assets/gui/controls/settings.png"
                        onClicked: root.pageEvent("Start.", { "object": "settings" })
                    }
                    IconButton {
                        height: 34
                        text: "关于"
                        icon: "qrc:/assets/gui/controls/about.png"
                        onClicked: root.pageEvent("Start.", { "object": "about" })
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Colors.transparent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Colors.changeA(Colors.border, 0.32)
                        }
                        GradientStop {
                            position: 0.55
                            color: Colors.changeA(Colors.border, 0.08)
                        }
                        GradientStop {
                            position: 1.0
                            color: Colors.changeA(Colors.border, 0.0)
                        }
                    }
                }
            }

            Item {
                id: recentHeading
                anchors.top: utilityPanel.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: root.compactLayout ? 20 : 28
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
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Constants.titleBarHeight + (root.compactLayout ? 24 : 44)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.compactLayout ? 24 : 40
                width: Math.min(460, Math.max(0, parent.width
                                              - (root.compactLayout ? 64 : 96)))

                Item {
                    id: startActions
                    anchors.fill: parent

                    Row {
                        id: actionRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        height: 140 * (root.compactLayout ? 0.88 : 1.0)
                        readonly property real minimumSpacing: 14
                        readonly property real maximumSpacing: 40
                        spacing: Math.min(maximumSpacing, minimumSpacing
                                          + Math.max(0, mainPanel.width - 400) * 0.08)
                        width: createProjectButton.width + openProjectButton.width + spacing

                        LargeIconButton {
                            id: createProjectButton
                            title: "创建"
                            subtitle: "新的xcshop项目"
                            icon: "qrc:/assets/gui/controls/new_project.png"
                            layout_width: mainContent.width
                            layout_amount: 2
                            minimumScale: root.compactLayout ? 0.88 : 1.0
                            onClicked: root.pageEvent("Start.", { "object": "create" })
                        }
                        LargeIconButton {
                            id: openProjectButton
                            title: "打开"
                            subtitle: "已有xcshop项目"
                            icon: "qrc:/assets/gui/controls/open_project.png"
                            layout_width: mainContent.width
                            layout_amount: 2
                            minimumScale: root.compactLayout ? 0.88 : 1.0
                            onClicked: projectFolderDialog.openXC("project",
                                                                  Global.recentProjects.length
                                                                  ? Global.recentProjects[0].path : APP_DIRPATH)
                        }
                    }

                }

            }
        }
    }
}
