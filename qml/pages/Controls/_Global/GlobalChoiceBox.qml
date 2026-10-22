pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

Item {
    id: root
    property var options: []
    property string currentValue: ""
    property string placeholderText: "请选择"
    property bool compact: false
    property bool menuOpened: false
    readonly property var menuOptions: {
        var entries = []
        var shulkers = null
        for (var i = 0; i < options.length; ++i) {
            var option = options[i]
            if (option.group === "shulker") {
                if (!shulkers) {
                    shulkers = { "text": "潜影盒（27 格）", "children": [] }
                    entries.push(shulkers)
                }
                shulkers.children.push(menuEntry(option))
            } else {
                entries.push(menuEntry(option))
            }
        }
        return entries
    }
    readonly property string currentLabel: {
        for (var i = 0; i < options.length; ++i)
            if (String(options[i].value) === currentValue)
                return String(options[i].label)
        return placeholderText
    }
    signal valueActivated(string value)
    width: 220
    height: 36

    function menuEntry(option) {
        return {
            "text": String(option.label),
            "value": String(option.value),
            "action": function() {
                root.currentValue = String(option.value)
                root.valueActivated(root.currentValue)
            }
        }
    }

    function openMenu() {
        if (!enabled || !options.length)
            return
        if (menuOpened) {
            SignalBus.contextMenuCloseRequested()
            return
        }
        menuOpened = true
        SignalBus.contextMenuRequested(root, 0, height + 6, menuOptions, null)
    }

    Component.onDestruction: if (menuOpened) SignalBus.contextMenuCloseRequested()
    onVisibleChanged: if (!visible && menuOpened) SignalBus.contextMenuCloseRequested()
    onEnabledChanged: if (!enabled && menuOpened) SignalBus.contextMenuCloseRequested()

    Connections {
        target: SignalBus
        function onContextMenuClosed() { root.menuOpened = false }
        function onContextMenuRequested(target, x, y, items, contentComponent) {
            if (target !== root)
                root.menuOpened = false
        }
    }

    Controls.Button {
        id: choice
        anchors.fill: parent
        leftPadding: 11
        rightPadding: 30
        onClicked: root.openMenu()
        contentItem: XCText {
            xcText: root.currentLabel
            onCenter: false
            verticalAlignment: Text.AlignVCenter
            xcFontSize: 13
            boldFont: false
            textColor: choice.enabled ? Colors.text : Colors.banned
        }
        background: Rectangle {
            radius: 8
            color: choice.down ? Colors.changeA(Colors.pressed, 0.96)
                              : (choice.hovered ? Colors.changeA(Colors.foreground, 0.94)
                                                : Colors.changeA(Colors.background, 0.56))
            border.width: 1
            border.color: root.menuOpened || choice.hovered ? Colors.changeA(Colors.border, 0.60)
                                                            : Colors.changeA(Colors.text, 0.10)
            Behavior on color { ColorAnimation { duration: 500 / Global.animationSpeed } }
            Behavior on border.color { ColorAnimation { duration: 500 / Global.animationSpeed } }
        }
        XCText {
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.menuOpened ? "⌃" : "⌄"
            xcFontSize: 14
            boldFont: false
            textColor: Colors.banned
        }
    }
}
