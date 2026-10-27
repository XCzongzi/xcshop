pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

Item {
    id: root
    // Strings use their index as value; object options carry value/label/group metadata.
    property var options: []
    property string currentValue: ""
    property string placeholderText: "请选择"
    property bool compact: false
    property bool menuOpened: false
    signal valueActivated(string value)
    width: 220
    height: 36

    function optionAt(index) {
        var option = options[index]
        return typeof option === "string" ? {
            value: String(index),
            label: option
        } : option
    }
    function menuEntry(option) {
        return {
            text: String(option.label),
            value: String(option.value),
            action: function () {
                root.currentValue = String(option.value)
                root.valueActivated(root.currentValue)
            }
        }
    }
    readonly property var menuOptions: {
        var entries = []
        var groups = ({})
        for (var index = 0; index < options.length; ++index) {
            var option = optionAt(index)
            if (option.group) {
                if (!groups[option.group]) {
                    groups[option.group] = {
                        text: String(option.groupLabel || option.group),
                        children: []
                    }
                    entries.push(groups[option.group])
                }
                groups[option.group].children.push(menuEntry(option))
            } else
                entries.push(menuEntry(option))
        }
        return entries
    }
    readonly property string currentLabel: {
        for (var index = 0; index < options.length; ++index) {
            var option = optionAt(index)
            if (String(option.value) === currentValue)
                return String(option.label)
        }
        return placeholderText
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
    Component.onDestruction: if (menuOpened)
        SignalBus.contextMenuCloseRequested()
    onVisibleChanged: if (!visible && menuOpened)
        SignalBus.contextMenuCloseRequested()
    onEnabledChanged: if (!enabled && menuOpened)
        SignalBus.contextMenuCloseRequested()
    Connections {
        target: SignalBus
        function onContextMenuClosed() {
            root.menuOpened = false
        }
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
        Keys.onEscapePressed: SignalBus.contextMenuCloseRequested()
        contentItem: XCText {
            xcText: root.currentLabel
            onCenter: false
            verticalAlignment: Text.AlignVCenter
            xcFontSize: root.compact ? 11 : 13
            boldFont: false
            textColor: choice.enabled ? Colors.text : Colors.banned
        }
        background: InputBackground {
            focused: root.menuOpened || choice.activeFocus
            idleOpacity: choice.down ? 0.80 : choice.hovered ? 0.68 : 0.56
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
