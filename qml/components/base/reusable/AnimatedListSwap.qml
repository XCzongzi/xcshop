import QtQuick
import xcshop

// 先把相邻两行移动至彼此的位置，再提交模型交换，保留委托与编辑状态。
QtObject {
    id: root
    property int index: -1
    property real previousExtent: 0
    property real currentExtent: 0
    property real progress: 0
    readonly property bool running: movement.running
    signal finished(int row)

    function begin(row, previousSize, currentSize) {
        if (running || row <= 0)
            return;
        index = row;
        previousExtent = previousSize;
        currentExtent = currentSize;
        progress = 0;
        movement.start();
    }
    function shiftFor(row) {
        if (index < 1)
            return 0;
        if (row === index)
            return -previousExtent * progress;
        return row === index - 1 ? currentExtent * progress : 0;
    }
    property NumberAnimation movement: NumberAnimation {
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 240 / Global.animationSpeed
        easing.type: Easing.InOutCubic
        onFinished: {
            root.finished(root.index);
            root.index = -1;
            root.progress = 0;
        }
    }
}
