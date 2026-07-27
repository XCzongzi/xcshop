import QtQuick
import xcshop

MouseArea{
    anchors.fill: parent
    hoverEnabled: true
    onEntered: {
        parent.color = Colors.fired
    }
    onExited: {
        parent.color = Colors.foreground
    }
    onPressed: {
        parent.color = Colors.pressed
        forceActiveFocus()
    }
    onReleased: {
        if (containsMouse) {
            parent.color = Colors.fired
        }else{
            parent.color = Colors.foreground
        }
    }
}