import QtQuick
import xcshop

Item {
    id: root
    property string text: ""
    property var options: []
    property int selected: -1
    property int initialOption: 0

    signal clicked()

    width: selectionControl.width
    height: selectionControl.height

    RadioGroup {
        id: selectionControl
        text: root.text
        options: root.options
        selected: root.selected
        initialOption: root.initialOption
        onClicked: {
            root.selected = selected
            root.clicked()
        }
    }

    Component.onCompleted: root.selected = root.initialOption
}
