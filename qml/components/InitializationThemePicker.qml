pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    objectName: "initializationThemePicker"
    clip: true

    property string mode: ""
    property string selectedTheme: ""
    property bool themeConfirmed: false
    property string hoveredMode: ""
    readonly property real tempo: Math.max(0.1, Global.animationSpeed)
    readonly property bool expanded: mode.length > 0
    readonly property var themes: Colors.colorSchemes.filter(function(scheme) {
        return scheme.mode === (root.mode === "dark" ? "深色" : "浅色")
    })
    property real split: mode === "dark" ? 0.30 : mode === "light" ? 0.70 : 0.5
    readonly property real dividerX: width * split
    readonly property real contentTop: Math.max(64, height * 0.12)
    readonly property real contentBottom: height - 96
    readonly property real dividerAngle: 12
    readonly property real dividerCenterY: (contentTop + contentBottom) / 2
    readonly property real dividerLength: Math.min(440, (contentBottom - contentTop) * 0.92)
    readonly property real dividerSlope: Math.tan(dividerAngle * Math.PI / 180)

    Behavior on split {
        NumberAnimation { duration: 420 / root.tempo; easing.type: Easing.InOutCubic }
    }

    function applyScheme(scheme) {
        if (Colors.colorScheme === scheme) return
        paletteTransition.stop()
        var previous = ({})
        for (var animation of paletteTransition.animations)
            previous[animation.properties] = Colors[animation.properties].toString()
        Colors.applyColorScheme(scheme)
        Colors.setThemeColor(Colors.accentForColorScheme(scheme) || Colors.accentChoices[0])
        for (var change of paletteTransition.animations) {
            change.from = previous[change.properties]
            change.to = Colors[change.properties].toString()
        }
        paletteTransition.start()
    }

    function finishPreview() {
        paletteTransition.complete()
    }

    function themeForMode(nextMode) {
        var requestedMode = nextMode === "dark" ? "深色" : "浅色"
        for (var scheme of Colors.colorSchemes) {
            if (scheme.id === Colors.colorScheme)
                return scheme.mode === requestedMode ? scheme.id : scheme.counterpart
        }
        return nextMode === "dark" ? "midnight" : "cloud"
    }

    function previewMode(nextMode) {
        if (expanded || !visible || hoveredMode === nextMode) return
        hoveredMode = nextMode
        applyScheme(themeForMode(nextMode))
    }

    function dividerAt(y) {
        return dividerX - (y - dividerCenterY) * dividerSlope
    }

    function chooseMode(nextMode) {
        if (expanded) return
        var scheme = themeForMode(nextMode)
        applyScheme(scheme)
        selectedTheme = themeConfirmed ? scheme : ""
        mode = nextMode
    }

    function back() {
        finishPreview()
        // Re-enabling hover under the return button must retain this mode's
        // current palette until the pointer crosses into the opposite mode.
        hoveredMode = mode
        selectedTheme = ""
        mode = ""
    }

    onVisibleChanged: if (!visible) finishPreview()

    ParallelAnimation {
        id: paletteTransition
        objectName: "initializationThemeColorTransition"
        // Animate the palette itself so the background, text and window chrome
        // change together. Reversing a preview starts at the current colors.
        ColorAnimation { target: Colors; properties: "backgroundColor"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "background_n"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "background"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "foreground"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "fired"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "pressed"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "paletteText"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "paletteMutedText"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "glass_highlight"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "themeColor"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
        ColorAnimation { target: Colors; properties: "border"; duration: 320 / root.tempo; easing.type: Easing.InOutQuad }
    }

    Repeater {
        model: ["dark", "light"]
        delegate: Item {
            id: modeOption
            required property string modelData
            readonly property bool dark: modelData === "dark"
            readonly property bool selected: root.mode === modelData
            objectName: "initializationMode_" + modelData
            x: dark ? 0 : root.dividerX
            width: dark ? root.dividerX : root.width - root.dividerX
            height: root.contentBottom
            opacity: !root.expanded || selected ? 1 : 0
            visible: opacity > 0
            enabled: !root.expanded
            Behavior on opacity {
                NumberAnimation { duration: 160 / root.tempo; easing.type: Easing.OutQuad }
            }

            Column {
                anchors.centerIn: parent
                spacing: 20
                scale: root.hoveredMode === modeOption.modelData && !root.expanded ? 1.05 : root.expanded ? 0.90 : 1
                Behavior on scale {
                    NumberAnimation { duration: 280 / root.tempo; easing.type: Easing.OutCubic }
                }
                // Small native vector marks retain crisp edges in either mode.
                Canvas {
                    id: modeIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48; height: 48
                    property color ink: Colors.text
                    onInkChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = ink
                        ctx.fillStyle = ink
                        ctx.lineWidth = 1.6
                        ctx.lineCap = "round"
                        if (modeOption.dark) {
                            ctx.beginPath()
                            ctx.arc(24, 24, 16, 0, Math.PI * 2)
                            ctx.fill()
                            ctx.globalCompositeOperation = "destination-out"
                            ctx.beginPath()
                            ctx.arc(32, 17, 15, 0, Math.PI * 2)
                            ctx.fill()
                        } else {
                            ctx.beginPath()
                            ctx.arc(24, 24, 9, 0, Math.PI * 2)
                            ctx.stroke()
                            for (var i = 0; i < 8; ++i) {
                                var angle = Math.PI * i / 4
                                ctx.beginPath()
                                ctx.moveTo(24 + Math.cos(angle) * 15, 24 + Math.sin(angle) * 15)
                                ctx.lineTo(24 + Math.cos(angle) * 20, 24 + Math.sin(angle) * 20)
                                ctx.stroke()
                            }
                        }
                    }
                }
                XCText {
                    onCenter: false
                    xcText: modeOption.dark ? "深色" : "浅色"
                    xcFontSize: 36
                    boldFont: false
                }
            }

        }
    }

    MouseArea {
        width: root.width; height: root.contentBottom
        enabled: !root.expanded
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.previewMode(mouseX < root.dividerAt(mouseY) ? "dark" : "light")
        onPositionChanged: mouse => root.previewMode(mouse.x < root.dividerAt(mouse.y) ? "dark" : "light")
        onExited: root.hoveredMode = ""
        onClicked: mouse => root.chooseMode(mouse.x < root.dividerAt(mouse.y) ? "dark" : "light")
    }

    Item {
        id: divider
        objectName: "initializationThemeDivider"
        x: root.dividerX - width / 2
        y: root.dividerCenterY - height / 2
        height: root.dividerLength
        width: 1
        rotation: root.dividerAngle
        Canvas {
            objectName: "initializationThemeDividerShadow"
            x: (parent.width - width) / 2; y: -36
            width: 73; height: parent.height + 72
            property color ink: Colors.text
            onInkChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var shadow = ctx.createLinearGradient(0, 0, width, 0)
                shadow.addColorStop(0, "transparent")
                shadow.addColorStop(0.2, "rgba(5, 5, 5, 0)")
                shadow.addColorStop(0.35, "rgba(5, 5, 5, 0.06)")
                shadow.addColorStop(0.5, "rgba(5, 5, 5, 0.16)")
                shadow.addColorStop(0.65, "rgba(5, 5, 5, 0.06)")
                shadow.addColorStop(0.8, "rgba(5, 5, 5, 0)")
                shadow.addColorStop(1, "transparent")
                ctx.fillStyle = shadow
                ctx.fillRect(0, 0, width, height)
                // Fade along the line as well as across it; the padded canvas
                // gives the shadow room to disappear without a clipped cap.
                ctx.globalCompositeOperation = "destination-in"
                var ends = ctx.createLinearGradient(0, 0, 0, height)
                var fade = Math.min(0.2, 64 / height)
                ends.addColorStop(0, "transparent")
                ends.addColorStop(fade, "white")
                ends.addColorStop(1 - fade, "white")
                ends.addColorStop(1, "transparent")
                ctx.fillStyle = ends
                ctx.fillRect(0, 0, width, height)
                ctx.globalCompositeOperation = "source-over"
                var line = ctx.createLinearGradient(0, 36, 0, height - 36)
                line.addColorStop(0, "transparent")
                line.addColorStop(0.08, Colors.changeA(ink, 0.24).toString())
                line.addColorStop(0.92, Colors.changeA(ink, 0.24).toString())
                line.addColorStop(1, "transparent")
                ctx.strokeStyle = line
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(width / 2, 36)
                ctx.lineTo(width / 2, height - 36)
                ctx.stroke()
            }
        }
    }

    ActionButton {
        objectName: "initializationThemeBack"
        x: root.mode === "dark" ? (root.dividerX - width) / 2
                                : root.dividerX + (root.width - root.dividerX - width) / 2
        y: root.contentBottom / 2 + 94
        text: "返回"
        buttonColor: Colors.transparent
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        enabled: root.expanded
        Behavior on opacity {
            NumberAnimation { duration: 240 / root.tempo; easing.type: Easing.OutCubic }
        }
        onClicked: root.back()
    }

    Item {
        id: themeList
        objectName: "initializationThemeList"
        visible: root.expanded
        y: root.dividerCenterY - height / 2
        width: root.width
        height: root.dividerLength * Math.cos(root.dividerAngle * Math.PI / 180) - 16
        readonly property real rowHeight: Math.min(62, (height - 5 * gap) / 6)
        readonly property real gap: 9
        readonly property real cardWidth: Math.min(380, (root.mode === "dark" ? root.width - root.dividerX : root.dividerX)
                                                 - root.dividerSlope * height / 2 - 36)
        readonly property real cardGap: 6

        Repeater {
            model: root.expanded ? root.themes : []
            delegate: Item {
                id: themeChoice
                required property var modelData
                required property int index
                objectName: "initializationTheme_" + modelData.id
                readonly property bool selected: root.selectedTheme === modelData.id
                property real reveal: 0
                readonly property real edgeTop: root.dividerAt(themeList.y + y)
                readonly property real edgeBottom: root.dividerAt(themeList.y + y + height)
                x: root.mode === "dark" ? Math.max(edgeTop, edgeBottom) + themeList.cardGap
                                        : Math.min(edgeTop, edgeBottom) - themeList.cardGap - width
                y: index * (themeList.rowHeight + themeList.gap)
                   + (themeList.height - 6 * themeList.rowHeight - 5 * themeList.gap) / 2
                width: themeList.cardWidth
                height: themeList.rowHeight
                opacity: Math.min(1, reveal)
                enabled: reveal >= 0.99

                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: (300 + themeChoice.index * 85) / root.tempo }
                    NumberAnimation { target: themeChoice; property: "reveal"; to: 1; duration: 460 / root.tempo; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                }

                Item {
                    id: entranceMask
                    objectName: "initializationThemeEntranceMask_" + themeChoice.modelData.id
                    // Keep the divider edge fixed while extending the other
                    // edge to the window, leaving room for the original rebound.
                    readonly property real outwardRoom: Math.max(24, root.mode === "dark"
                        ? root.width - themeChoice.x - themeChoice.width : themeChoice.x)
                    x: root.mode === "dark" ? 0 : -outwardRoom
                    width: themeChoice.width + outwardRoom
                    height: themeChoice.height
                    clip: true

                    Item {
                        x: (root.mode === "light" ? entranceMask.outwardRoom : 0)
                           + (root.mode === "dark" ? -1 : 1) * width * (1 - themeChoice.reveal)
                        width: themeChoice.width; height: themeChoice.height
                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: Colors.changeA(Colors.card, themePointer.containsMouse ? 0.40 : 0.16)
                            border.width: themeChoice.selected ? 2 : 1
                            border.color: themeChoice.selected ? Colors.accentFill : Colors.changeA(Colors.text, 0.12)
                            Behavior on color { ColorAnimation { duration: 160 / root.tempo } }
                            Rectangle {
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                width: 52; height: Math.min(34, parent.height - 12); radius: 5
                                color: themeChoice.modelData.background
                                border.width: 1; border.color: Colors.changeA(themeChoice.modelData.text, 0.15)
                                Rectangle { x: 7; y: 7; width: 24; height: 5; radius: 2; color: themeChoice.modelData.foreground }
                                Rectangle { x: 7; y: 16; width: 17; height: 8; radius: 2; color: themeChoice.modelData.surface }
                                Rectangle { x: 29; y: 16; width: 15; height: 8; radius: 2; color: Colors.accentForColorScheme(themeChoice.modelData.id) || Colors.accentChoices[0] }
                            }
                            XCText {
                                x: 80; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 126
                                onCenter: false; xcText: themeChoice.modelData.name
                                xcFontSize: 14; boldFont: themeChoice.selected
                            }
                            Canvas {
                                anchors.right: parent.right; anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16
                                visible: themeChoice.selected
                                property color ink: Colors.accentText
                                onInkChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.strokeStyle = ink
                                    ctx.lineWidth = 1.8
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(2, 8)
                                    ctx.lineTo(6, 12)
                                    ctx.lineTo(14, 4)
                                    ctx.stroke()
                                }
                            }
                        }
                        MouseArea {
                            id: themePointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.applyScheme(themeChoice.modelData.id)
                                root.themeConfirmed = true
                                root.selectedTheme = themeChoice.modelData.id
                            }
                        }
                    }
                }
            }
        }
    }
}
