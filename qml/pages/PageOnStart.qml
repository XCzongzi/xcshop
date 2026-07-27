pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true

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

    component StartActionCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string iconSource: ""
        property bool hovered: false
        property bool pressed: false
        signal clicked()

        height: 184
        radius: 13
        color: card.pressed ? Colors.changeA(Colors.pressed, 0.94)
                            : (card.hovered ? Colors.changeA(Colors.foreground, 0.96)
                                            : Colors.changeA(Colors.foreground, 0.78))
        border.width: 1
        border.color: card.hovered ? Colors.changeA(Colors.border, 0.68)
                                   : Colors.changeA(Colors.text, 0.10)

        layer.enabled: true
        layer.effect: XCShadow { shadowVerticalOffset: card.hovered ? 7 : 4 }

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Rectangle {
            width: 4
            height: parent.height - 36
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: Colors.border
        }

        LightEffect {
            z: 0
            anchors.fill: parent
            lightSource_x: actionMouse.mouseX
            lightSource_y: actionMouse.mouseY
            lightSource_r: 60
            blur: 1.4
            lightColor: Colors.border
            opacity: card.hovered ? 0.92 : 0.42
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        Image {
            z: 1
            x: 24
            y: 25
            width: 56
            height: 56
            source: card.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true
            mipmap: true
        }

        Column {
            z: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            spacing: 5

            XCText { xcText: card.title; onCenter: false; xcFontSize: 21 }
            XCText {
                width: parent.width
                xcText: card.subtitle
                onCenter: false
                xcFontSize: 13
                boldFont: false
                textColor: Colors.banned
            }
        }

        MouseArea {
            id: actionMouse
            z: 2
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                card.hovered = true
                card.y = -5
            }
            onExited: {
                card.hovered = false
                card.pressed = false
                card.y = 0
            }
            onPressed: card.pressed = true
            onReleased: card.pressed = false
            onClicked: card.clicked()
        }
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.97)

        Rectangle {
            id: sidebar
            width: Math.max(232, Math.min(300, parent.width * 0.28))
            height: parent.height
            color: Colors.changeA(Colors.foreground, 0.76)
            border.width: 1
            border.color: Colors.changeA(Colors.text, 0.08)

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 24
                spacing: 10

                Rectangle {
                    width: 48
                    height: 48
                    radius: 14
                    color: Colors.changeA(Colors.border, 0.20)
                    border.width: 1
                    border.color: Colors.changeA(Colors.border, 0.55)
                    Image {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        source: "qrc:/assets/gui/png/logo.png"
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Item { width: 1; height: 6 }
                XCText { xcText: "XCShop"; onCenter: false; xcFontSize: 25 }
                XCText {
                    width: parent.width
                    xcText: "Minecraft 商店数据包编辑器"
                    onCenter: false
                    xcFontSize: 12
                    boldFont: false
                    textColor: Colors.banned
                }
            }

            Rectangle {
                id: recentCard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                y: 176
                height: 190
                radius: 11
                color: Colors.changeA(Colors.background, 0.35)
                border.width: 1
                border.color: Colors.changeA(Colors.text, 0.08)

                XCText { x: 16; y: 15; xcText: "最近项目"; onCenter: false; xcFontSize: 14 }
                Rectangle {
                    visible: Global.recentProjects.length === 0
                    x: 16
                    y: 47
                    width: 34
                    height: 34
                    radius: 10
                    color: Colors.changeA(Colors.pressed, 0.64)
                    XCText { anchors.centerIn: parent; xcText: "·"; xcFontSize: 22; textColor: Colors.banned }
                }
                XCText {
                    visible: Global.recentProjects.length === 0
                    x: 60
                    y: 49
                    xcText: "还没有最近打开的项目"
                    onCenter: false
                    xcFontSize: 12
                    boldFont: false
                    textColor: Colors.banned
                }
                XCText {
                    visible: Global.recentProjects.length === 0
                    x: 16
                    y: 103
                    width: parent.width - 32
                    xcText: "创建新项目，或打开已有项目开始编辑。"
                    onCenter: false
                    xcFontSize: 11
                    boldFont: false
                    textColor: Colors.changeA(Colors.text, 0.55)
                }
                ListView {
                    id: recentList
                    visible: Global.recentProjects.length > 0
                    x: 12
                    y: 43
                    width: parent.width - 24
                    height: parent.height - y - 12
                    clip: true
                    spacing: 6
                    model: Global.recentProjects
                    delegate: Rectangle {
                        id: recentEntry
                        required property int index
                        required property var model
                        width: recentList.width
                        height: 43
                        radius: 7
                        color: recentMouse.containsMouse ? Colors.changeA(Colors.pressed, 0.86)
                                                       : Colors.changeA(Colors.background, 0.30)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            x: 9
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: 7
                            color: Colors.changeA(Colors.border, 0.22)
                            XCText { anchors.centerIn: parent; xcText: "P"; xcFontSize: 11; textColor: Colors.border }
                        }
                        XCText {
                            x: 42
                            y: 7
                            width: parent.width - x - 10
                            xcText: recentEntry.model.name
                            onCenter: false
                            xcFontSize: 12
                        }
                        XCText {
                            x: 42
                            y: 24
                            width: parent.width - x - 10
                            xcText: recentEntry.model.namespace + (recentEntry.model.version ? " / " + recentEntry.model.version : "")
                            onCenter: false
                            xcFontSize: 10
                            boldFont: false
                            textColor: Colors.banned
                        }
                        MouseArea {
                            id: recentMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.openProject(recentEntry.model.path)
                        }
                    }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                spacing: 10

                Rectangle { width: parent.width; height: 1; color: Colors.changeA(Colors.text, 0.09) }
                Row {
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

        Rectangle {
            x: sidebar.width
            width: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Colors.changeA(Colors.text, 0.10)
        }

        Item {
            id: workspace
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Column {
                width: Math.min(790, parent.width - 88)
                anchors.centerIn: parent
                spacing: 14

                XCText { xcText: "START HERE"; onCenter: false; xcFontSize: 12; textColor: Colors.border }
                XCText { xcText: "开始创作你的商店"; onCenter: false; xcFontSize: 32 }
                XCText {
                    width: parent.width
                    xcText: "创建一个全新的 XCShop 项目，或继续编辑已有的项目文件。"
                    onCenter: false
                    xcFontSize: 15
                    boldFont: false
                    textColor: Colors.banned
                }
                Item { width: 1; height: 10 }

                Row {
                    id: actionRow
                    width: parent.width
                    spacing: 16
                    StartActionCard {
                        width: (actionRow.width - actionRow.spacing) / 2
                        title: "创建项目"
                        subtitle: "从模板和目标版本开始配置"
                        iconSource: "qrc:/assets/gui/controls/new_project.png"
                        onClicked: root.pageEvent("Start.", { "object": "create" })
                    }
                    StartActionCard {
                        width: (actionRow.width - actionRow.spacing) / 2
                        title: "打开项目"
                        subtitle: "继续编辑已保存的项目内容"
                        iconSource: "qrc:/assets/gui/controls/open_project.png"
                        onClicked: projectFolderDialog.openXC("project",
                                                              Global.recentProjects.length
                                                              ? Global.recentProjects[0].path : APP_DIRPATH)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 10
                    color: Colors.changeA(Colors.foreground, 0.48)
                    border.width: 1
                    border.color: Colors.changeA(Colors.text, 0.08)
                    XCText {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        xcText: "准备就绪"
                        onCenter: false
                        xcFontSize: 13
                        textColor: Colors.border
                    }
                    XCText {
                        anchors.left: parent.left
                        anchors.leftMargin: 88
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        xcText: "选择上方操作以开始使用 XCShop。"
                        onCenter: false
                        xcFontSize: 12
                        boldFont: false
                        textColor: Colors.banned
                    }
                }
            }
        }
    }
}
