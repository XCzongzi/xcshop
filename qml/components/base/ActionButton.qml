import QtQuick
import xcshop

// Shared action roles for dialogs, settings and workspace tools.
TextButton {
    id: root
    property bool primary: false
    property bool destructive: false

    height: 34
    radius: 7
    textSize: 13
    widthBorderSize: 12
    boldFont: false
    buttonColor: primary ? Colors.accentFill : destructive ? Colors.changeA(Colors.error, 0.14) : Colors.changeA(Colors.control, 0.72)
    firedColor: primary ? Qt.rgba(1, 1, 1, 0.14) : destructive ? Colors.changeA(Colors.error, 0.25) : Colors.changeA(Colors.fired, 0.85)
    pressedColor: primary ? Qt.rgba(0, 0, 0, 0.18) : destructive ? Colors.changeA(Colors.error, 0.36) : Colors.pressed
    color: enabled ? buttonColor : Colors.changeA(Colors.card, 0.4)
    textColor: !enabled ? Colors.changeA(Colors.text, 0.45) : primary ? Colors.accentContent : Colors.text
}
