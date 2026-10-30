pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

BasePage {
    id: root
    objectName: "aboutPage"
    fullScreen: true
    x: 0
    usePageScrollBar: false
    color: sheetColor

    readonly property color sheetColor: Colors.background_n
    readonly property color ink: Colors.paletteText
    readonly property color mutedInk: Colors.paletteMutedText
    readonly property real coverHeight: Math.max(240, height - 142)
    readonly property real expandedCoverHeight: Math.min(220, height * 0.32)
    readonly property real revealOffset: coverHeight - expandedCoverHeight
    readonly property real pagePadding: width < 700 ? 24 : 48
    readonly property real columnWidth: Math.max(0, Math.min(880, width - pagePadding * 2))
    property bool expanded: false
    property string linkFeedback: ""

    function revealInformation() {
        if (expanded) return
        expanded = true
        view.cancelFlick()
        revealAnimation.to = Math.min(revealOffset, view.contentHeight - view.height)
        revealAnimation.start()
    }

    function openLink(url) {
        linkFeedback = Qt.openUrlExternally(url) ? "" : "无法打开浏览器，请手动访问：" + url
    }

    component AboutText: Text {
        color: root.ink
        font.family: "Microsoft YaHei"
        font.pixelSize: 13
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }

    component SectionTitle: AboutText {
        font.pixelSize: 18
        font.weight: Font.DemiBold
    }

    component LinkCard: Controls.AbstractButton {
        id: card
        required property string title
        required property string subtitle
        required property string mark
        required property url destination
        property bool sponsor: false
        readonly property color accent: sponsor ? (Colors.isLight ? "#7251ad" : "#c2a4f2") : root.ink
        implicitHeight: sponsor ? 94 : 82
        hoverEnabled: true
        Accessible.name: title + "，" + subtitle + "，在浏览器中打开"
        onClicked: root.openLink(destination)

        background: Rectangle {
            radius: 12
            color: card.sponsor
                   ? Qt.tint(root.sheetColor, Colors.changeA(card.accent, card.down ? 0.23 : card.hovered ? 0.18 : 0.10))
                   : Qt.tint(root.sheetColor, Colors.changeA(root.ink, card.down ? 0.12 : card.hovered ? 0.08 : 0.035))
            border.width: 1
            border.color: card.activeFocus || card.hovered || card.sponsor
                          ? Colors.changeA(card.accent, card.sponsor ? 0.48 : 0.35)
                          : Colors.changeA(root.ink, 0.10)
            Behavior on color { ColorAnimation { duration: 140 / Global.animationSpeed } }
        }
        contentItem: Item {
            Rectangle {
                x: 18; anchors.verticalCenter: parent.verticalCenter
                width: 42; height: 42; radius: 12
                color: Colors.changeA(card.accent, 0.10)
                AboutText {
                    anchors.centerIn: parent
                    text: card.mark
                    color: card.accent
                    font.pixelSize: card.sponsor ? 23 : 14
                    font.bold: true
                }
            }
            Column {
                x: 74; anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - x - 42); spacing: 5
                AboutText {
                    width: parent.width; text: card.title; color: card.accent
                    font.pixelSize: card.sponsor ? 18 : 15; font.weight: Font.DemiBold
                }
                AboutText { width: parent.width; text: card.subtitle; color: root.mutedInk; font.pixelSize: 12 }
            }
            AboutText {
                anchors.right: parent.right; anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "↗"; color: card.accent; font.pixelSize: 19
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Flickable {
        id: view
        objectName: "aboutScrollView"
        anchors.fill: parent
        contentWidth: width
        contentHeight: root.coverHeight + sheet.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true
        onMovementStarted: {
            if (!root.expanded) root.expanded = true
            revealAnimation.stop()
        }
        // First wheel gesture reveals the profile; later gestures scroll normally.
        WheelHandler {
            target: null
            enabled: !root.expanded || revealAnimation.running
            onWheel: function(event) {
                var delta = event.pixelDelta.y || event.angleDelta.y
                if (event.inverted) delta = -delta
                if (delta < 0 || revealAnimation.running) {
                    root.revealInformation()
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }
        }
        Controls.ScrollBar.vertical: XCScrollBar {
            objectName: "aboutScrollBar"
            visible: root.expanded && size < 1
        }

        Item {
            width: view.width
            height: root.coverHeight
            clip: true
            Image {
                id: cover
                objectName: "aboutCover"
                width: parent.width; height: parent.height
                // Keep the horizon visible as the cover scrolls away.
                y: view.contentY * 0.5
                source: "qrc:/assets/backgrounds/麦田.png"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Colors.isLight ? "#ccffffff" : "#99000000" }
                    GradientStop { position: 0.26; color: "transparent" }
                    GradientStop { position: 1; color: "#33000000" }
                }
            }
        }

        Rectangle {
            id: sheet
            objectName: "aboutInformation"
            y: root.coverHeight
            width: view.width
            height: information.y + information.height + 40
            color: root.sheetColor

            Rectangle {
                id: avatar
                objectName: "aboutAvatar"
                x: (parent.width - width) / 2
                y: -height * 2 / 3
                width: 102; height: width; radius: width / 2
                color: "#000000"
                border.width: 5
                border.color: root.sheetColor
                Image {
                    anchors.fill: parent; anchors.margins: 19
                    source: "qrc:/assets/gui/png/logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
            Column {
                id: identity
                y: avatar.height / 3 + 12
                width: root.columnWidth
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                AboutText {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: "Minecraft xcshop"; font.pixelSize: 28; font.weight: Font.DemiBold
                }
                AboutText {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: "XCzongzi / 小菜粽子"; color: root.mutedInk; font.pixelSize: 12
                }
                AboutText {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    visible: !root.expanded
                    text: "向下滚动或点击，了解更多 ↓"; color: root.mutedInk; font.pixelSize: 11
                }
            }

            Column {
                id: information
                y: identity.y + identity.height + 36
                width: root.columnWidth
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28

                Column {
                    width: parent.width; spacing: 16
                    SectionTitle { text: "软件信息" }
                    Column {
                        width: parent.width; spacing: 0
                        Repeater {
                            model: [
                                { label: "软件版本", value: "v" + (Qt.application.version || "—") },
                                { label: "软件用途", value: "Minecraft Java 版商店数据包编辑与构建" },
                                { label: "编辑模块", value: "UI 界面 · 物品 · 代价 · 展示" },
                                { label: "构建方式", value: "模板套件 + 外部构建器" }
                            ]
                            delegate: Item {
                                id: fact
                                required property var modelData
                                width: parent.width
                                height: Math.max(42, factValue.implicitHeight + 22)
                                AboutText { y: 11; width: 90; text: fact.modelData.label; color: root.mutedInk }
                                AboutText { id: factValue; x: 104; y: 11; width: parent.width - x; text: fact.modelData.value }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Colors.changeA(root.ink, 0.07) }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width; spacing: 14
                    SectionTitle { text: "开发者" }
                    AboutText { text: "XCzongzi"; font.pixelSize: 16; font.weight: Font.DemiBold }
                    AboutText { text: "小菜粽子 · 本软件开发者"; color: root.mutedInk }
                    Flow {
                        width: parent.width; spacing: 12
                        LinkCard {
                            objectName: "aboutGithub"
                            width: parent.width < 540 ? parent.width : (parent.width - 12) / 2
                            title: "GitHub"; subtitle: "@XCzongzi"; mark: "GH"
                            destination: "https://github.com/XCzongzi"
                        }
                        LinkCard {
                            objectName: "aboutBilibili"
                            width: parent.width < 540 ? parent.width : (parent.width - 12) / 2
                            title: "bilibili"; subtitle: "小菜粽子 · 个人空间"; mark: "哔"
                            destination: "https://space.bilibili.com/481184316"
                        }
                    }
                }

                Column {
                    width: parent.width; spacing: 14
                    SectionTitle { text: "赞助开发者" }
                    AboutText { width: parent.width; text: "如果这个工具对你有帮助，欢迎支持我的开发。"; color: root.mutedInk }
                    LinkCard {
                        objectName: "aboutSponsor"
                        width: parent.width
                        sponsor: true; title: "在爱发电支持小菜粽子"
                        subtitle: "自愿赞助 · 感谢每一份支持"; mark: "♥"
                        destination: "https://afdian.com/a/xczongzi"
                    }
                    AboutText {
                        width: parent.width; color: root.mutedInk; font.pixelSize: 12
                        text: "赞助说明：赞助为自愿支持，不是购买软件或服务，不承诺更新频率、功能上线时间、定制开发或优先技术支持。请根据自身情况理性支持；具体赞助方案与支付规则以爱发电页面为准。"
                    }
                }

                AboutText {
                    visible: root.linkFeedback.length > 0
                    width: parent.width; text: root.linkFeedback; color: Colors.warning
                }
                AboutText {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: "由 XCzongzi 用心制作"; color: root.mutedInk; font.pixelSize: 11
                }
            }

            // Only the cover state needs this overlay; expanded links remain interactive.
            MouseArea {
                objectName: "aboutRevealArea"
                anchors.fill: parent
                visible: !root.expanded
                cursorShape: Qt.PointingHandCursor
                onClicked: root.revealInformation()
            }
        }
    }

    NumberAnimation {
        id: revealAnimation
        target: view; property: "contentY"
        duration: 520 / Global.animationSpeed
        easing.type: Easing.OutCubic
    }

    // Give the fixed navigation its own surface once the photo leaves the viewport.
    Rectangle {
        width: parent.width
        height: Constants.titleBarHeight + 64
        color: root.sheetColor
        opacity: Math.max(0, Math.min(1, (view.contentY - root.coverHeight + height) / 48))
        visible: opacity > 0
    }

    ActionButton {
        objectName: "aboutBack"
        x: 20; y: Constants.titleBarHeight + 16
        height: 34; text: "← 返回"
        buttonColor: Colors.changeA(root.sheetColor, 0.92)
        textColor: root.ink
        onClicked: root.pageEvent("About.back", {})
    }
}
