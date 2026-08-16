import QtQuick
import xcshop

TextButton {
    id: root
    colorAnimationEnabled: false
    width: parent ? parent.width : implicitWidth
    height: 40
    radius: 7
    textSize: 15
    widthBorderSize: 10
    buttonColor: Colors.changeA(Colors.fired, 0)
    pressedColor: Colors.changeA(Colors.border, 0.30)
}
