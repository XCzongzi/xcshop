pragma ComponentBehavior: Bound
import QtQuick
import xcshop
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

Rectangle{  
    id: root
    property int lightSource_x: 0
    property int lightSource_y: height / 2
    property int lightSource_r: 50
    property double blur: 50
    property color lightColor: Colors.ambientAccent


    radius: parent.radius
    width: parent.width
    height: parent.height
    color:Colors.transparent
    Rectangle{
        color: root.lightColor
        x: Math.min(Math.max(root.lightSource_x - root.lightSource_r,-root.lightSource_r), root.width - root.lightSource_r)
        y: Math.min(Math.max(root.lightSource_y - root.lightSource_r,-root.lightSource_r), root.height - root.lightSource_r)
        width: 2*root.lightSource_r
        height: width
        radius: root.lightSource_r
    }
    layer.enabled: true
    layer.effect:MultiEffect{
        blurEnabled: true
        blur: 1
        blurMax: root.blur<1 ? 96 * root.blur : 96
        blurMultiplier: root.blur<1 ? 1 : root.blur
        brightness: 0.2
        autoPaddingEnabled: false
        layer.enabled: true
        layer.effect: OpacityMask{
            maskSource: Rectangle{
                width: root.width
                height: root.height
                radius: root.radius
            }
        }
    }
}
