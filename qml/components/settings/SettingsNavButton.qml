import QtQuick
import xcshop

TextButton {
    id: root
    property bool selected: false
    btnSelected: selected
    width: parent ? parent.width : implicitWidth
    height: 40
    radius: 7
    textSize: 15
    widthBorderSize: 10
    buttonColor: Colors.transparent
    pressedColor: Colors.changeA(Colors.border, 0.30)
}
