import QtQuick
import xcshop

// 离散的展开或内容切换使用动画；内容自身逐帧调整高度时直接跟随，避免二次缓动。
Item {
    id: root
    property bool expanded: false
    property real contentHeight: contentItem.childrenRect.height
    property bool ready: false
    property bool contentAnimating: false
    default property alias content: contentItem.data
    readonly property bool animating: reveal.running
    clip: true
    visible: height > 0
    enabled: expanded && !reveal.running
    function updateHeight(animate) {
        var destination = expanded ? contentHeight : 0;
        if (!ready)
            return;
        if (animate) {
            reveal.stop();
            reveal.from = height;
            reveal.to = destination;
            reveal.start();
        } else {
            reveal.stop();
            height = destination;
        }
    }
    onExpandedChanged: updateHeight(true)
    onContentHeightChanged: updateHeight(!contentAnimating)
    onContentAnimatingChanged: {
        if (contentAnimating)
            updateHeight(false);
    }
    Component.onCompleted: {
        ready = true;
        updateHeight(false);
    }
    Item {
        id: contentItem
        width: root.width
    }
    NumberAnimation {
        id: reveal
        target: root
        property: "height"
        duration: 120 / Global.animationSpeed
        easing.type: Easing.InOutQuad
    }
}
