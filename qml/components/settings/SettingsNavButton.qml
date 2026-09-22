import QtQuick
import xcshop

TextButton {
    id: root
    colorAnimationEnabled: false
    width: parent ? parent.width : implicitWidth
    height: 40
    radius: 8
    textSize: 14
    widthBorderSize: 10
    boldFont: false
    buttonColor: Colors.transparent
    firedColor: Colors.changeA(Colors.background_n, 0.22)
    pressedColor: Colors.changeA(Colors.pressed, 0.58)
}
