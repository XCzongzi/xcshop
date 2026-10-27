import QtQuick
import xcshop

// Index-based compatibility API for existing editor fields.
ChoiceBox {
    id: root
    property int per_width: 200
    property int per_height: 32
    property int selected: 0
    property alias opened: root.menuOpened
    signal clicked
    width: per_width
    height: per_height
    currentValue: String(selected)
    onSelectedChanged: currentValue = String(selected)
    onValueActivated: function (value) {
        selected = Number(value)
        clicked()
    }
}
