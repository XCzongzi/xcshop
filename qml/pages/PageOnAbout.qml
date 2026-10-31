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
    readonly property string releaseDate: "待公布"
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

    component AboutFact: Item {
        id: fact
        required property string label
        required property string value
        property bool showUpdate: false
        implicitHeight: Math.max(42, factValue.implicitHeight + 22)
        height: implicitHeight
        AboutText { y: 11; width: 90; text: fact.label; color: root.mutedInk }
        AboutText {
            id: factValue
            x: 104; y: 11
            width: Math.max(0, parent.width - x - (fact.showUpdate ? updateBadge.width + 6 : 0))
            text: fact.value
            wrapMode: fact.showUpdate ? Text.NoWrap : Text.Wrap
            elide: Text.ElideRight
        }
        Controls.AbstractButton {
            id: updateBadge
            objectName: "aboutUpdateBadge"
            visible: fact.showUpdate
            x: factValue.x + Math.min(factValue.implicitWidth, factValue.width) + 6
            y: 5
            width: implicitWidth
            implicitWidth: badgeLabel.implicitWidth + 8
            implicitHeight: 30
            hoverEnabled: true
            Accessible.name: "有新版本，查看更新"
            onClicked: root.pageEvent("Updates.show", {})
            background: Rectangle {
                radius: 5
                color: Colors.changeA(Colors.accentText, updateBadge.down ? 0.20 : updateBadge.hovered ? 0.13 : 0.07)
                border.width: updateBadge.activeFocus ? 1 : 0
                border.color: Colors.accentText
            }
            contentItem: AboutText {
                id: badgeLabel
                text: "[有新版本]"
                color: Colors.accentText
                font.pixelSize: 12
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Colors.changeA(root.ink, 0.07) }
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
                    Row {
                        width: parent.width; spacing: 24
                        AboutFact {
                            objectName: "aboutSoftwareVersion"
                            width: (parent.width - parent.spacing) / 2
                            label: "软件版本"; value: "v" + (Qt.application.version || "—")
                            showUpdate: Updates.updateAvailable
                        }
                        AboutFact {
                            objectName: "aboutDataVersionLimit"
                            width: (parent.width - parent.spacing) / 2
                            label: "数据版本上限"; value: String(BuildKits.dataVersion)
                        }
                    }
                    AboutFact {
                        objectName: "aboutReleaseDate"
                        width: parent.width
                        label: "发布时间"; value: root.releaseDate
                    }
                }

                Controls.AbstractButton {
                    id: moreInfoButton
                    objectName: "aboutMoreInformation"
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: moreInfoLabel.implicitWidth + 24
                    implicitHeight: 34
                    checkable: true
                    hoverEnabled: true
                    Accessible.name: checked ? "收起更多信息" : "展开更多信息"
                    background: Rectangle {
                        radius: 7
                        color: Colors.changeA(root.ink, moreInfoButton.down ? 0.10 : moreInfoButton.hovered ? 0.06 : 0)
                        border.width: moreInfoButton.activeFocus ? 1 : 0
                        border.color: Colors.changeA(root.ink, 0.35)
                    }
                    contentItem: Item {
                        Row {
                            id: moreInfoLabel
                            anchors.centerIn: parent
                            spacing: 7
                            Canvas {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12; height: 8
                                property color strokeColor: root.mutedInk
                                onStrokeColorChanged: requestPaint()
                                rotation: moreInfoReveal.progress * 180
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = strokeColor
                                    ctx.lineWidth = 1.5
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.beginPath(); ctx.moveTo(1, 1); ctx.lineTo(6, 6); ctx.lineTo(11, 1); ctx.stroke()
                                }
                            }
                            AboutText { text: "更多信息"; color: root.mutedInk }
                        }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Item {
                    id: moreInfoReveal
                    objectName: "aboutMoreInformationContent"
                    width: parent.width
                    property real progress: moreInfoButton.checked ? 1 : 0
                    height: (moreInfoText.implicitHeight + 16) * progress
                    clip: true
                    visible: height > 0
                    enabled: moreInfoButton.checked
                    Behavior on progress {
                        NumberAnimation {
                            duration: 280 / Global.animationSpeed
                            easing.type: Easing.OutCubic
                        }
                    }
                    AboutText {
                        id: moreInfoText
                        y: 8
                        width: parent.width
                        color: root.mutedInk
                        lineHeight: 1.6
                        text: "这里是更多信息的临时说明，后续会替换为正式内容。\n\n"
                              + "xcshop 用于编辑和构建 Minecraft Java 版商店数据包，可以组织商店布局、商品、代价与展示文本。\n\n"
                              + "这里还可以补充项目介绍、版本变化与使用说明。感谢你使用 xcshop，欢迎分享建议与反馈。"
                    }
                }
            }

            Column {
                width: parent.width; spacing: 14
                SectionTitle { text: "开发者" }
                Item {
                    width: parent.width
                    height: Math.max(developerIdentity.height, websiteRow.height)
                    Column {
                        id: developerIdentity
                        spacing: 14
                        AboutText { text: "XCzongzi"; font.pixelSize: 16; font.weight: Font.DemiBold }
                        AboutText { text: "小菜粽子"; color: root.mutedInk }
                    }
                    Row {
                        id: websiteRow
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 6
                        AboutText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "个人网站："; color: root.mutedInk
                        }
                        Controls.AbstractButton {
                            id: websiteLink
                            objectName: "aboutWebsite"
                            text: "xczongzi.net"
                            implicitWidth: contentItem.implicitWidth
                            implicitHeight: 24
                            hoverEnabled: true
                            Accessible.name: "个人网站：xczongzi.net，在浏览器中打开"
                            onClicked: root.openLink("https://xczongzi.net")
                            contentItem: AboutText {
                                text: websiteLink.text
                                color: Colors.accentText
                                verticalAlignment: Text.AlignVCenter
                                font.underline: websiteLink.hovered || websiteLink.down || websiteLink.activeFocus
                            }
                            background: Item {}
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
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
