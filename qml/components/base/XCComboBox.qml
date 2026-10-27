pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtQuick.Templates as T
import xcshop

T.ComboBox {
    id: root
    // Pages supply stable business keys; Qt owns highlighting and activation.
    property var options: []
    property string value: ""
    property string placeholderText: "请选择"
    property string emptyText: "暂无可用选项"
    property bool compact: false
    property int selectionRevision: 0
    signal valueActivated(string value)

    implicitWidth: 200
    implicitHeight: compact ? 30 : 36
    leftPadding: 10
    rightPadding: 30
    hoverEnabled: true
    enabled: count > 0
    font.family: "微软雅黑"
    font.pixelSize: compact ? 11 : 13
    model: options
    textRole: "label"
    valueRole: "value"
    currentIndex: {
        root.options
        root.count
        root.selectionRevision
        for (var i = 0; i < options.length; ++i)
            if (String(options[i].value) === value) return i
        return -1
    }
    readonly property string currentLabel: currentIndex >= 0 ? currentText
            : value.length ? "不可用的选项：" + value
            : count ? placeholderText : emptyText

    onActivated: function(index) {
        var option = options[index]
        if (option && option.enabled !== false)
            valueActivated(String(option.value))
        // The owner commits the value. Rejected selections keep the saved value.
        ++selectionRevision
    }
    onVisibleChanged: if (!visible) popup.close()
    onEnabledChanged: if (!enabled) popup.close()
    function syncSelection() { ++selectionRevision }
    onOptionsChanged: Qt.callLater(syncSelection)
    Component.onCompleted: syncSelection()

    // Track ancestors too: the field can move while its page scrolls or resizes.
    readonly property point anchorPosition: {
        var geometry = 0
        var item = root
        while (item) {
            geometry += item.x + item.y + item.width + item.height + item.scale + item.rotation
            item = item.parent
        }
        return isFinite(geometry) ? root.mapToItem(null, 0, 0) : Qt.point(0, 0)
    }
    readonly property real windowWidth: Window.width
    readonly property real windowHeight: Window.height
    FontMetrics { id: metrics; font: root.font }
    readonly property real listWidth: {
        var measured = root.width
        for (var i = 0; i < options.length; ++i)
            measured = Math.max(measured, metrics.advanceWidth(String(options[i].label)) + (options[i].swatch ? 78 : 58))
        return Math.min(Math.max(root.width, 360), measured)
    }

    contentItem: XCText {
        xcText: root.currentLabel
        onCenter: false
        verticalAlignment: Text.AlignVCenter
        xcFontSize: root.font.pixelSize
        boldFont: false
        textColor: !root.enabled || root.currentIndex < 0 ? Colors.banned : Colors.text
    }
    indicator: Canvas {
        x: root.width - width - 11
        y: (root.height - height) / 2
        width: 12; height: 8
        property color strokeColor: root.enabled ? Colors.text : Colors.banned
        onStrokeColorChanged: requestPaint()
        rotation: root.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 160 / Global.animationSpeed; easing.type: Easing.OutCubic } }
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
    background: Rectangle {
        radius: 7
        color: Colors.changeA(Colors.background, 0.36)
        border.width: 1
        border.color: root.popup.visible || root.visualFocus ? Colors.changeA(Colors.border, 0.82)
                                                             : Colors.changeA(Colors.text, 0.10)
        opacity: root.enabled ? 1 : 0.6
        Behavior on border.color { ColorAnimation { duration: 160 / Global.animationSpeed } }
        ButtonStateOverlay {
            hovered: root.hovered
            pressed: root.down
            stateEnabled: root.enabled
            hoverColor: Colors.changeA(Colors.fired, 0.12)
            pressedColor: Colors.changeA(Colors.pressed, 0.24)
            cornerRadius: 7
        }
    }

    delegate: T.ItemDelegate {
        id: entry
        required property int index
        required property var modelData
        readonly property bool startsGroup: !!modelData.group
                && (index === 0 || modelData.group !== root.options[index - 1].group)
        readonly property real headingHeight: startsGroup ? 26 : 0
        readonly property bool selected: root.currentIndex === index
        width: choices.width
        height: headingHeight + (root.compact ? 30 : 34)
        enabled: modelData.enabled !== false
        hoverEnabled: true
        highlighted: root.highlightedIndex === index
        text: String(modelData.label)
        leftPadding: 28 + (swatch.visible ? 20 : 0)
        rightPadding: 10
        topPadding: headingHeight
        bottomPadding: 0
        font: root.font
        contentItem: XCText {
            xcText: entry.text
            xcFontSize: root.font.pixelSize
            boldFont: false
            onCenter: false
            verticalAlignment: Text.AlignVCenter
            textColor: entry.enabled ? Colors.text : Colors.banned
        }
        background: Item {
            Rectangle {
                y: entry.headingHeight
                width: parent.width
                height: parent.height - y
                radius: 5
                color: entry.selected ? Colors.changeA(Colors.border, 0.14) : Colors.transparent
                ButtonStateOverlay {
                    hovered: entry.hovered || entry.highlighted
                    pressed: entry.down
                    stateEnabled: entry.enabled
                    hoverColor: Colors.changeA(Colors.fired, 0.18)
                    pressedColor: Colors.changeA(Colors.pressed, 0.36)
                    cornerRadius: 5
                }
            }
        }
        Rectangle {
            visible: entry.selected
            x: 11; y: entry.headingHeight + (entry.height - entry.headingHeight - height) / 2
            width: 6; height: 6; radius: 3
            color: Colors.border
        }
        Rectangle {
            id: swatch
            visible: !!entry.modelData.swatch
            x: 28; y: entry.headingHeight + (entry.height - entry.headingHeight - height) / 2
            width: 12; height: 12; radius: 3
            color: entry.modelData.swatch || Colors.transparent
            border.width: 1; border.color: Colors.changeA(Colors.text, 0.20)
        }
        Item {
            visible: entry.startsGroup
            width: parent.width; height: entry.headingHeight
            XCText {
                x: 10; anchors.verticalCenter: parent.verticalCenter
                xcText: String(entry.modelData.groupLabel || entry.modelData.group)
                xcFontSize: 11; boldFont: false; onCenter: false; textColor: Colors.banned
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        }
    }

    popup: T.Popup {
        id: optionsPopup
        objectName: "comboPopup"
        readonly property real below: Math.max(0, root.windowHeight - root.anchorPosition.y - root.height - 12)
        readonly property real above: Math.max(0, root.anchorPosition.y - 12)
        width: Math.min(root.listWidth, Math.max(0, root.windowWidth - 16))
        height: Math.min(choices.contentHeight + padding * 2, 300, Math.max(above, below))
        x: Math.max(8 - root.anchorPosition.x, Math.min(0, root.windowWidth - 8 - root.anchorPosition.x - width))
        y: below >= height || below >= above ? root.height + 4 : -height - 4
        padding: 5
        modal: false
        dim: false
        margins: 8
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 / Global.animationSpeed } }
        contentItem: ListView {
            id: choices
            objectName: "comboOptions"
            clip: true
            model: root.delegateModel
            currentIndex: root.highlightedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            onDraggingChanged: if (dragging) wheelMotion.stop()
            NumberAnimation {
                id: wheelMotion
                target: choices
                property: "contentY"
                duration: 120 / Global.animationSpeed
                easing.type: Easing.OutCubic
            }
            WheelHandler {
                target: null
                onWheel: function(event) {
                    var delta = event.pixelDelta.y || event.angleDelta.y
                    if (!delta) {
                        event.accepted = false
                        return
                    }
                    // Accumulate wheel steps; reversing direction responds immediately.
                    var start = wheelMotion.running && (wheelMotion.to - choices.contentY) * delta < 0
                            ? wheelMotion.to : choices.contentY
                    wheelMotion.stop()
                    choices.cancelFlick()
                    var destination = Math.max(choices.originY, Math.min(start - delta,
                            choices.originY + Math.max(0, choices.contentHeight - choices.height)))
                    if (event.pixelDelta.y) {
                        // Touchpads already provide smooth motion and momentum.
                        choices.contentY = destination
                    } else {
                        wheelMotion.from = choices.contentY
                        wheelMotion.to = destination
                        wheelMotion.start()
                    }
                    event.accepted = true
                }
            }
            Controls.ScrollBar.vertical: XCScrollBar {
                onPressedChanged: if (pressed) wheelMotion.stop()
            }
            onCurrentIndexChanged: {
                wheelMotion.stop()
                if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            }
        }
        onAboutToHide: wheelMotion.stop()
        onOpened: choices.positionViewAtIndex(Math.max(0, root.highlightedIndex), ListView.Contain)
        background: FrostedSurface {
            radius: 7
            backdropAnchor: root
        }
    }
}
