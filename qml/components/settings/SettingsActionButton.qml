import QtQuick
import xcshop

TextButton {
    id: root
    property bool primary: false
    readonly property color accentTextColor: {
        // Choose a readable label even when the user changes the accent.
        function linear(value) {
            return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        }
        var luminance = 0.2126 * linear(Colors.themeColor.r)
                + 0.7152 * linear(Colors.themeColor.g)
                + 0.0722 * linear(Colors.themeColor.b)
        return luminance > 0.179 ? "#000000" : "#ffffff"
    }

    height: 32
    radius: 6
    textSize: 12
    widthBorderSize: 12
    boldFont: false
    buttonColor: primary ? Colors.themeColor : Colors.changeA(Colors.pressed, 0.72)
    firedColor: primary ? Qt.rgba(1, 1, 1, 0.14) : Colors.changeA(Colors.fired, 0.85)
    pressedColor: primary ? Qt.rgba(0, 0, 0, 0.18) : Colors.pressed
    color: enabled ? buttonColor : Colors.changeA(Colors.foreground, 0.4)
    textColor: enabled ? (primary ? root.accentTextColor : Colors.text) : Colors.changeA(Colors.text, 0.45)
}
