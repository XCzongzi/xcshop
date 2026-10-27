pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true
    readonly property bool compactLayout: height < 560 || width < 900
    property bool creatingProject: false

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
        Global.version = projectInfo.version ? String(projectInfo.version) : ""
        Global.current_element = "Global"
        Global.rememberProject(projectPath, projectInfo)
        pageEvent("Start.", { "object": "projectOpened" })
    }

    function openCreation() {
        creatingProject = true
    }

    function closeCreation() {
        creatingProject = false
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

        Item {
            id: startBackdrop
            anchors.fill: parent

            // Capture the image and ambient gradient together, without any
            // cards or controls, so hover blur preserves the background tint.
            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: Global.mainWindow_backdrop
                live: true
                sourceRect: {
                    var geometry = 0
                    var items = [startBackdrop, sourceItem]
                    for (var index = 0; index < items.length; ++index) {
                        var item = items[index]
                        while (item) {
                            geometry += item.x + item.y + item.width + item.height
                                    + item.scale + item.rotation
                            item = item.parent
                        }
                    }
                    if (!isFinite(geometry) || !sourceItem)
                        return Qt.rect(0, 0, 0, 0)
                    return startBackdrop.mapToItem(sourceItem,
                                                   Qt.rect(0, 0, width, height))
                }
            }

            AmbientBackground {
                anchors.fill: parent
                animated: true
            }
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
                        color: Colors.changeA(
                                   Qt.tint(Colors.panel,
                                           Colors.changeA(Colors.border, 0.18)),
                                   Global.backgroundMode === "color" ? 0.48 : 0.62)
                    }
                    GradientStop {
                        position: 0.46
                        color: Colors.changeA(Colors.panel,
                                              Global.backgroundMode === "color" ? 0.34 : 0.48)
                    }
                    GradientStop {
                        position: 1.0
                        color: Colors.changeA(
                                   Qt.tint(Colors.background_n,
                                           Colors.changeA(Colors.border, 0.10)),
                                   Global.backgroundMode === "color" ? 0.22 : 0.34)
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

            XCText {
                visible: Global.recentProjects.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: recentHeading.bottom
                anchors.topMargin: 48
                onCenter: false
                xcText: "暂无最近打开的项目"
                xcFontSize: 14
                boldFont: false
                textColor: Colors.banned
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
                opacity: root.creatingProject ? 0 : 1
                enabled: !root.creatingProject
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160 / Global.animationSpeed
                        easing.type: Easing.OutCubic
                    }
                }

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
                            onClicked: root.openCreation()
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

            PageOnCreating {
                id: creationPage
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Constants.titleBarHeight
                z: 1
                visible: root.creatingProject
                // PageOnCreating is normally a top-level page.  Here it is
                // created with the start page and simply hidden until needed.
                fullScreen: false
                mainWindow: root.mainWindow
                backdropSource: startBackdrop
                embeddedBackAction: function() {
                    root.closeCreation()
                }
            }

            Connections {
                target: creationPage

                function onPageEvent(signalType, parameters) {
                    switch (signalType) {
                    case "Creating.back":
                        root.closeCreation()
                        break
                    case "Popup.show":
                    case "Popup.close":
                    case "Creating.projectCreated":
                        root.pageEvent(signalType, parameters)
                        break
                    }
                }
            }
        }
    }
}
