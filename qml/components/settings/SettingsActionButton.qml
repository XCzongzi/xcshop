import QtQuick
import xcshop

TextButton {
    height: 32
    radius: 6
    textSize: 12
    widthBorderSize: 12
    boldFont: false
    buttonColor: Colors.changeA(Colors.pressed, 0.72)
    firedColor: Colors.changeA(Colors.fired, 0.85)
    color: enabled ? buttonColor : Colors.changeA(Colors.foreground, 0.4)
    textColor: enabled ? Colors.text : Colors.changeA(Colors.text, 0.45)
}
