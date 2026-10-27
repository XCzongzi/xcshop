import QtQuick
import xcshop

Rectangle{
    id: root
    width: 8
    height: parent.height
    x: parent.width - width
    color: Colors.transparent

    property int content_height: height
    property int height_output: scroller.y * (content_height/height)
    property int wheelDeltaY: 0
    property bool layout_determines//绑定决定布局变化的变量，在父控件中
    // Some views synchronise contentY bi-directionally with this control.
    // They can turn this off to avoid the handle animation feeding an old
    // position back into the view while it is scrolling.
    property bool animatePosition: true
    readonly property bool dragging: mouseArea.pressed
    visible: content_height > height

    onLayout_determinesChanged:{   //在页面变化时重置高度，防止出错
        scroller.y = 0
    }
    function wheel(){
        scroller.y = Math.max(mouseArea.drag.minimumY, Math.min(mouseArea.drag.maximumY, (scroller.y - wheelDeltaY * root.height / root.content_height)))
    }
    function setContentOffset(offset){
        var maxOffset = Math.max(0, root.content_height - root.height)
        var boundedOffset = Math.max(0, Math.min(maxOffset, offset))
        scroller.y = maxOffset > 0 ? boundedOffset * (root.height - scroller.height) / maxOffset : 0
    }

    Rectangle{
        id: scroller
        color: mouseArea.pressed ? Colors.border : Colors.changeA(Colors.banned, mouseArea.containsMouse ? 0.8 : 0.45)
        width: 8
        radius: 3
        height:Math.max(30,root.height/(root.content_height/root.height))

        MouseArea{
            id: mouseArea
            anchors.fill: parent
            drag.target: scroller
            drag.axis: Drag.YAxis
            drag.minimumY: 0
            drag.maximumY: root.height - scroller.height
            hoverEnabled: true
        }
        Behavior on color {
            ColorAnimation {
            duration: 500 / Global.animationSpeed
            }
        }
        Behavior on y{
            enabled: root.animatePosition && !root.dragging
            NumberAnimation {
                duration: 30 / Global.animationSpeed
                easing.type: Easing.InOutQuad
            }
        }
    }
}
