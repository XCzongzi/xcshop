import QtQuick
import xcshop

QtObject {
    id: root
    property int index: -1
    property real offset: 0
    readonly property bool running: movement.running
    signal finished(int row)
    function begin(row, extent) {
        if (running)
            return;
        index = row;
        offset = 0;
        movement.to = extent;
        movement.start();
    }
    function shiftFor(row) {
        return index >= 0 && row > index ? -offset : 0;
    }
    property NumberAnimation movement: NumberAnimation {
        target: root
        property: "offset"
        duration: 120 / Global.animationSpeed
        easing.type: Easing.InCubic
        onFinished: {
            root.finished(root.index);
            root.index = -1;
            root.offset = 0;
        }
    }
}
