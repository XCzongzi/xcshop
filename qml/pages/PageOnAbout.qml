pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Controls.impl as Impl
import Qt5Compat.GraphicalEffects
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
    readonly property real expandedCoverHeight: coverHeight * 21 / 115
    readonly property real revealOffset: coverHeight - expandedCoverHeight
    readonly property real coverScroll: Math.max(0, Math.min(view.contentY, revealOffset))
    readonly property real headerOffset: Math.max(0, view.contentY - revealOffset)
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

    function restoreCover() {
        if (view.contentY <= 1 && !revealAnimation.running) return
        revealAnimation.stop()
        view.cancelFlick()
        revealAnimation.to = 0
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
        required property url iconSource
        property color iconColor: Colors.transparent
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
                Impl.IconImage {
                    objectName: card.objectName + "Icon"
                    anchors.centerIn: parent
                    width: 28; height: 28
                    source: card.iconSource
                    color: card.iconColor
                    fillMode: Image.PreserveAspectFit
                }
            }
            Column {
                x: 74; anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - x - 18); spacing: 5
                AboutText {
                    width: parent.width; text: card.title; color: card.accent
                    font.pixelSize: card.sponsor ? 18 : 15; font.weight: Font.DemiBold
                }
                AboutText { width: parent.width; text: card.subtitle; color: root.mutedInk; font.pixelSize: 12 }
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Flickable {
        id: view
        objectName: "aboutScrollView"
        anchors.fill: parent
        contentWidth: width
        contentHeight: root.coverHeight + sheet.height + information.height + 40
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true
        onMovementStarted: {
            revealAnimation.stop()
            root.expanded = true
        }
        onContentYChanged: {
            if (!revealAnimation.running && contentY <= 1) root.expanded = false
        }
        onMovementEnded: {
            if (!revealAnimation.running && contentY <= 1) root.expanded = false
        }
        // Returning to the cover rearms the same reveal gesture.
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
            objectName: "aboutCoverViewport"
            y: root.headerOffset
            z: 1
            width: view.width
            height: root.coverHeight
            clip: true
            Image {
                id: cover
                objectName: "aboutCover"
                width: parent.width; height: parent.height
                // Stop the parallax together with the pinned cover.
                y: root.coverScroll * 0.5
                source: "qrc:/assets/backgrounds/麦田.png"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Colors.isLight ? "#ccffffff" : "#99000000" }
                    GradientStop { position: 0.26; color: "transparent" }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            Rectangle {
                objectName: "aboutCoverFade"
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.min(180, parent.height * 0.35)
                gradient: Gradient {
                    GradientStop { position: 0; color: Colors.changeA(root.sheetColor, 0) }
                    GradientStop { position: 0.45; color: Colors.changeA(root.sheetColor, 0.32) }
                    GradientStop { position: 1; color: root.sheetColor }
                }
            }
            MouseArea {
                objectName: "aboutCoverArea"
                anchors.fill: parent
                cursorShape: root.expanded ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.restoreCover()
            }
        }

        Rectangle {
            id: sheet
            objectName: "aboutProfileHeader"
            y: root.coverHeight + root.headerOffset
            z: 2
            width: view.width
            height: identity.y + identity.height + 36
            color: root.sheetColor

            // Keep scrolled links beneath the opaque profile from receiving clicks.
            MouseArea { anchors.fill: parent }

            Rectangle {
                id: avatar
                objectName: "aboutAvatar"
                x: (parent.width - width) / 2
                y: -Math.min(height * 2 / 3, root.coverHeight - root.coverScroll)
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
                objectName: "aboutIdentity"
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

            MouseArea {
                objectName: "aboutRevealArea"
                anchors.fill: parent
                visible: !root.expanded
                cursorShape: Qt.PointingHandCursor
                onClicked: root.revealInformation()
            }
        }

        Column {
            id: information
            objectName: "aboutInformation"
            y: root.coverHeight + sheet.height
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
                            { label: "软件用途", value: "Minecraft Java 版商店数据包编辑与构建" }
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
                AboutText { text: "小菜粽子"; color: root.mutedInk }
                Flow {
                    width: parent.width; spacing: 12
                    LinkCard {
                        objectName: "aboutGithub"
                        width: parent.width < 540 ? parent.width : (parent.width - 12) / 2
                        title: "GitHub"; subtitle: "@XCzongzi"
                        iconSource: Colors.isLight ? "qrc:/assets/gui/brands/github-black.svg"
                                                   : "qrc:/assets/gui/brands/github-white.svg"
                        destination: "https://github.com/XCzongzi"
                    }
                    LinkCard {
                        objectName: "aboutBilibili"
                        width: parent.width < 540 ? parent.width : (parent.width - 12) / 2
                        title: "bilibili"; subtitle: "@小菜粽子"
                        iconSource: "qrc:/assets/gui/brands/bilibili.svg"
                        iconColor: "#00a1d6"
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
                    subtitle: "感谢支持"
                    iconSource: "qrc:/assets/gui/brands/afdian.png"
                    destination: "https://afdian.com/a/xczongzi"
                }
                AboutText {
                    width: parent.width; color: root.mutedInk; font.pixelSize: 12
                    text: "赞助说明：赞助为自愿支持，不是购买软件或服务，不承诺更新频率、功能上线时间、定制开发或优先技术支持，请根据自身情况理性支持。"
                }
            }

            AboutText {
                visible: root.linkFeedback.length > 0
                width: parent.width; text: root.linkFeedback; color: Colors.warning
            }
            AboutText {
                objectName: "aboutFooter"
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: "Made by XCzongzi."; color: root.mutedInk; font.pixelSize: 11
            }
        }

        Item {
            id: contentEdge
            objectName: "aboutContentEdge"
            y: sheet.y + sheet.height - 1
            z: 3
            width: view.width
            height: 40
            opacity: Math.min(1, root.headerOffset / 24)
            visible: opacity > 0
            clip: true

            // Sample only the scrolling content to avoid capturing this effect.
            Loader {
                anchors.fill: parent
                active: contentEdge.visible && width > 0 && GraphicsInfo.api !== GraphicsInfo.Software
                sourceComponent: Rectangle {
                    id: edgeBlur
                    readonly property int padding: 12
                    color: root.sheetColor

                    ShaderEffectSource {
                        id: edgeCapture
                        x: -edgeBlur.padding; y: -edgeBlur.padding
                        width: contentEdge.width + edgeBlur.padding * 2
                        height: contentEdge.height + edgeBlur.padding * 2
                        sourceItem: information
                        sourceRect: Qt.rect(-information.x + x,
                                            contentEdge.y - information.y + y, width, height)
                        visible: false
                        live: true
                    }
                    Rectangle {
                        id: blurMask
                        width: edgeCapture.width; height: edgeCapture.height
                        visible: false
                        layer.enabled: true
                        gradient: Gradient {
                            GradientStop { position: 0; color: "white" }
                            GradientStop { position: edgeBlur.padding / blurMask.height; color: "white" }
                            GradientStop { position: 1 - edgeBlur.padding / blurMask.height; color: "transparent" }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                    MaskedBlur {
                        x: edgeCapture.x; y: edgeCapture.y
                        width: edgeCapture.width; height: edgeCapture.height
                        source: edgeCapture
                        maskSource: blurMask
                        radius: 12
                        samples: 25
                    }
                }
            }

            // Match the fixed header and soften the edge on software renderers too.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: root.sheetColor }
                    GradientStop { position: 0.35; color: Colors.changeA(root.sheetColor, 0.72) }
                    GradientStop { position: 1; color: Colors.changeA(root.sheetColor, 0) }
                }
            }
        }

    }

    NumberAnimation {
        id: revealAnimation
        target: view; property: "contentY"
        duration: 520 / Global.animationSpeed
        easing.type: Easing.OutCubic
        onFinished: root.expanded = view.contentY > 1
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
