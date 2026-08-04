pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import Qt5Compat.GraphicalEffects

Item {
    id: selectionMask
    z: 98.5
    x: 0
    y: 0
    width: parent.width
    height: parent.height
    //height: elementRelayBar.visible ? elementRelayBar.y : root.height
    visible: false
    opacity: 0

    property real holeX: 0
    property real holeY: 0
    property real holeWidth: 0
    property real holeHeight: 0
    property color maskColor: Colors.changeA(Colors.shadow, 0.78)

    Behavior on opacity { NumberAnimation { duration: 200 } }
    NumberAnimation{
        id:destroy
        target: selectionMask
        property: "opacity"
        to: 0
        duration: 120
        onFinished: {
            selectionMask.visible = false
        }
    }

    function updateHole(sceneRect) {
        if (!sceneRect || sceneRect.width === undefined)
            return
        var rootScene = root.mapToItem(null, 0, 0)  //继承Main中的root
        var padding = 7
        var left = sceneRect.x - rootScene.x - padding
        var top = sceneRect.y - rootScene.y - padding
        var right = left + sceneRect.width + padding * 2
        var bottom = top + sceneRect.height + padding * 2
        holeX = Math.max(0, Math.min(width, left))
        holeY = Math.max(0, Math.min(height, top))
        holeWidth = Math.max(0, Math.min(width, right) - holeX)
        holeHeight = Math.max(0, Math.min(height, bottom) - holeY)
    }

    

    Rectangle{  //遮罩视觉效果
        color: selectionMask.maskColor
        width: parent.width
        height: parent.height

        layer.enabled:true
        layer.effect: OpacityMask{
            maskSource: Rectangle{
                width:selectionMask.width
                height:selectionMask.height
                color: Colors.transparent
                Rectangle{
                    x: selectionMask.holeX
                    y: selectionMask.holeY
                    width: selectionMask.holeWidth
                    height: selectionMask.holeHeight
                    radius: 12
                }
            }
            invert: true
        }
    }
    component MaskPart: MouseArea {
        hoverEnabled: true
        onClicked:{
            SignalBus.elementSelectionDeselect()
        }
        }
    //鼠标交互遮罩
    MaskPart {
        x: 0
        y: 0
        width: parent.width
        height: selectionMask.holeY
    }
    MaskPart {
        x: 0
        y: selectionMask.holeY
        width: selectionMask.holeX
        height: selectionMask.holeHeight
    }
    MaskPart {
        x: selectionMask.holeX + selectionMask.holeWidth
        y: selectionMask.holeY
        width: Math.max(0, parent.width - x)
        height: selectionMask.holeHeight
    }
    MaskPart {
        x: 0
        y: selectionMask.holeY + selectionMask.holeHeight
        width: parent.width
        height: Math.max(0, parent.height - y)
    }
    

    Connections {
        target: SignalBus
        function onElementSelectionFocusChanged(active, sceneRect) {
            if (active){
                selectionMask.visible = true
                selectionMask.opacity = 1
                selectionMask.updateHole(sceneRect)
            }else{
                destroy.start()
            }
        }
    }
}