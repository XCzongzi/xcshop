import QtQuick
import xcshop


FocusScope{
    id: root

    property bool delayExpand: false

    property int min_width: -1
    property bool expanded: false  //展开动画播放完毕后，此项将设为真。若此项初始时便为真，则意为取消动画
    property int contentHeight
    property color color: Colors.changeA(Colors.foreground, 0.72)
    height: 0
    clip: true
    enabled: height > 0

    Binding{    //展开动画播放后，实时更新组件高度
        target: root
        property: "height"
        value: root.contentHeight
        when: root.expanded
        restoreMode: Binding.RestoreNone
    }

    function expand(){
        expandAnimation.start()
    }

    Rectangle{
        color: root.color
        radius: 12
        
        anchors.fill: root

        opacity: (hoverHandler.hovered || root.activeFocus) ? 1 : 0.92

        property double borderOpacity: (hoverHandler.hovered || root.activeFocus) ? 0.72 : 0.13
        border.color: Colors.changeA(Colors.border,borderOpacity)
        border.width: 1
        Behavior on borderOpacity{
            enabled: !root.activeFocus
            NumberAnimation{
                duration: 180
            }
        }
        

        //展开动画（创建时）
            NumberAnimation{
                id: expandAnimation
                target: root
                property: "height"
                from: 0
                to: root.contentHeight
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [1.00, 0.00, 0.40, 1.33,1,1]
                onFinished: {
                    root.expanded = true
                }
            }
        Component.onCompleted: {
            if(!root.delayExpand && !root.expanded)expandAnimation.start()
            if(root.expanded){
                root.expanded = false   //这样可以暂时取消高度动画
                root.height = root.contentHeight
                root.expanded = true
            }
        }


        //基础动画
        Behavior on color {
                ColorAnimation{
                duration: 180
                }
            }
        Behavior on opacity {
                NumberAnimation{
                    duration: 300
                }
            }

        HoverHandler{       //监测鼠标的悬停事件
            id: hoverHandler
        }

        MouseArea{
            anchors.fill: parent
            onClicked: forceActiveFocus(root)
        }
    }

}
