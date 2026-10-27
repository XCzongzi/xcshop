pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true
    content_height: aboutContent.height + 32

    property string githubUrl: "https://github.com/XCzongzi"
    property string version: "0.1.0"
    property real visualContentOffset: height_output

    Behavior on visualContentOffset {
        NumberAnimation {
            duration: 180 / Global.animationSpeed
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        anchors.rightMargin: 8
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.97)
        clip: true

        Item {
            id: aboutContent
            width: parent.width
            height: aboutColumn.y + aboutColumn.height + 48
            y: -root.visualContentOffset

            Image {
                id: heroImage
                width: parent.width
                height: Math.min(340, Math.max(230, parent.width * 0.42))
                fillMode: Image.PreserveAspectCrop
                source: "qrc:/assets/gui/png/about.png"
                sourceSize.width: width
                sourceSize.height: height
                asynchronous: true
            }

            Rectangle {
                anchors.fill: heroImage
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Colors.changeA(Colors.background, 0.08) }
                    GradientStop { position: 0.58; color: Colors.changeA(Colors.background, 0.34) }
                    GradientStop { position: 1.0; color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.98) }
                }
            }

            Rectangle {
                id: avatarFrame
                z: 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: heroImage.height - height / 2
                width: 118
                height: 118
                radius: width / 2
                color: Colors.changeA(Colors.background, 0.92)
                border.width: 4
                border.color: Colors.changeA(Colors.border, 0.92)

                Item {
                    id: avatarMask
                    anchors.fill: parent
                    anchors.margins: 6
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: avatarMask.width
                            height: avatarMask.height
                            radius: width / 2
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: "qrc:/assets/gui/png/logo.png"
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }
            }

            Column {
                id: aboutColumn
                width: Math.min(760, parent.width - 56)
                anchors.horizontalCenter: parent.horizontalCenter
                y: heroImage.height + 44
                spacing: 16

                Rectangle {
                    id: identityCard
                    width: parent.width
                    height: 138
                    radius: 14
                    color: Colors.changeA(Colors.card, 0.88)
                    border.width: 1
                    border.color: Colors.changeA(Colors.outline, 0.11)

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        XCText {
                            width: parent.width
                            xcText: "XCShop"
                            onCenter: true
                            xcFontSize: 28
                        }
                        XCText {
                            width: parent.width
                            xcText: "Minecraft 服务端商店数据包的可视化生成工具"
                            onCenter: true
                            xcFontSize: 14
                            boldFont: false
                            textColor: Colors.banned
                        }
                        Item { width: 1; height: 4 }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            Rectangle {
                                width: versionText.width + 18
                                height: 24
                                radius: 12
                                color: Colors.changeA(Colors.border, 0.23)
                                XCText {
                                    id: versionText
                                    anchors.centerIn: parent
                                    xcText: "v" + root.version
                                    xcFontSize: 11
                                    textColor: Colors.accentText
                                }
                            }
                            XCText {
                                anchors.verticalCenter: parent.verticalCenter
                                xcText: "开发者：XCzongzi · 小菜粽子"
                                onCenter: false
                                xcFontSize: 12
                                boldFont: false
                                textColor: Colors.banned
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: projectColumn.height + 36
                    radius: 12
                    color: Colors.changeA(Colors.card, 0.70)
                    border.width: 1
                    border.color: Colors.changeA(Colors.outline, 0.09)

                    Column {
                        id: projectColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 20
                        spacing: 10

                        XCText {
                            width: parent.width
                            xcText: "项目与反馈"
                            onCenter: false
                            xcFontSize: 18
                        }
                        Row {
                            spacing: 10
                            TextButton {
                                text: "访问 GitHub"
                                height: 34
                                radius: 7
                                textSize: 13
                                widthBorderSize: 12
                                buttonColor: Colors.changeA(Colors.border, 0.56)
                                firedColor: Colors.changeA(Colors.border, 0.74)
                                pressedColor: Colors.changeA(Colors.border, 0.86)
                                onClicked: Qt.openUrlExternally(root.githubUrl)
                            }
                            XCText {
                                anchors.verticalCenter: parent.verticalCenter
                                xcText: "github.com/XCzongzi"
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

        TextButton {
            z: 2
            x: 16
            y: 16
            height: 32
            radius: 6
            text: "← 返回"
            textSize: 13
            widthBorderSize: 10
            buttonColor: Colors.changeA(Colors.background, 0.68)
            firedColor: Colors.changeA(Colors.card, 0.92)
            onClicked: root.pageEvent("About.back", {})
        }
    }
}
