pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true
    readonly property bool compactLayout: height < 560

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

    component ActionCard: Rectangle {
        id: card
        property string title: ""
        property string iconSource: ""
        property string shortcutText: ""
        property bool hovered: false
        property bool pressed: false
        readonly property real compactScale: root.compactLayout ? 0.82 : 1.0
        signal clicked()

        height: Math.round(136 * compactScale)
        radius: 16
        color: hovered ? Colors.changeA(Colors.pressed, 1.0) : Colors.changeA(Colors.foreground, 1.0)
        border.width: 1
        border.color: Colors.changeA(Colors.text, hovered ? 0.20 : 0.10)

        layer.enabled: true
        layer.effect: XCShadow {
            shadowColor: Colors.changeA(Colors.shadow, card.hovered ? 0.68 : 0.52)
            shadowBlur: card.hovered ? 0.76 : 0.68
            shadowHorizontalOffset: 2
            shadowVerticalOffset: card.hovered ? 5 : 4
        }

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        scale: pressed ? 0.98 : 1.0

        LightEffect {
            z: 0
            anchors.fill: parent
            lightSource_x: actionMouse.mouseX
            lightSource_y: actionMouse.mouseY
            lightSource_r: 80
            blur: 1.5
            lightColor: Colors.changeA(Colors.text, 0.12)
            opacity: card.hovered ? 0.22 : 0.12
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Image {
            x: Math.round(24 * compactScale)
            y: Math.round(24 * compactScale)
            width: Math.round(56 * compactScale)
            height: width
            source: card.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        Rectangle {
            visible: card.shortcutText.length > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 20
            anchors.rightMargin: 20
            width: shortcut.width + 16
            height: 23
            radius: 7
            color: Colors.changeA(Colors.background, 0.22)
            border.width: 1
            border.color: Colors.changeA(Colors.text, 0.12)
            XCText {
                id: shortcut
                anchors.centerIn: parent
                xcText: card.shortcutText
                xcFontSize: 10
                textColor: Colors.changeA(Colors.text, 0.80)
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.round(20 * compactScale)
            anchors.rightMargin: Math.round(20 * compactScale)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(19 * compactScale)
            spacing: 5

            XCText { xcText: card.title; onCenter: false; xcFontSize: Math.round(19 * compactScale) }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: { card.hovered = true; card.y = -4 }
            onExited: { card.hovered = false; card.pressed = false; card.y = 0 }
            onPressed: card.pressed = true
            onReleased: card.pressed = false
            onClicked: card.clicked()
        }
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

        Rectangle {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 10
            color: Colors.changeA(Colors.border, recentEntry.hovered ? 0.28 : 0.18)
            XCText { anchors.centerIn: parent; xcText: "P"; xcFontSize: 12; textColor: Colors.border }
        }
        XCText {
            x: 57
            y: 10
            width: parent.width - x - 14
            xcText: recentEntry.model.name
            onCenter: false
            xcFontSize: 13
        }
        XCText {
            x: 57
            y: 31
            width: parent.width - x - 14
            xcText: recentEntry.model.namespace + (recentEntry.model.version ? "  ·  " + recentEntry.model.version : "")
            onCenter: false
            xcFontSize: 10
            boldFont: false
            textColor: Colors.banned
            elide: Text.ElideRight
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: recentEntry.hovered = true
            onExited: { recentEntry.hovered = false; recentEntry.pressed = false }
            onPressed: recentEntry.pressed = true
            onReleased: recentEntry.pressed = false
            onClicked: root.openProject(recentEntry.model.path)
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
        }
        Rectangle {
            visible: Global.backgroundMode === "color"
            width: 420
            height: 420
            x: -210
            y: parent.height - 230
            radius: width / 2
            color: Colors.changeA(Colors.border, 0.045)
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
                        XCText { xcText: "XCShop"; onCenter: false; xcFontSize: 22 }
                        XCText {
                            xcText: "Minecraft 商店数据包编辑器"
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
                            ActionCard {
                                width: (actionRow.width - actionRow.spacing) / 2
                                title: "创建项目"
                                iconSource: "qrc:/assets/gui/controls/new_project.png"
                                shortcutText: "新建"
                                onClicked: root.pageEvent("Start.", { "object": "create" })
                            }
                            ActionCard {
                                width: (actionRow.width - actionRow.spacing) / 2
                                title: "打开项目"
                                iconSource: "qrc:/assets/gui/controls/open_project.png"
                                shortcutText: "选择文件夹"
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
                    border.width: 1
                    border.color: Colors.changeA(Colors.text, 0.10)

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
