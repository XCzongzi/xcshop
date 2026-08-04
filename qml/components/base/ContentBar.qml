import QtQuick
import xcshop


FocusScope{
    id: root

    property bool deferInitialExpand: false

    property int min_width: -1
    property bool expandAnimationEnabled: true  //创建完成后将自动变为false并将高度动画切换到一般模式
    property bool resizeAnimationEnabled: true
    property int height_expand    //用于初始创建动画
    property color color: Colors.changeA(Colors.foreground, 0.72)
    height: 0
    clip: true
    enabled: height > 0

    Behavior on height {    //创建完毕后的一般高度动画
        enabled: !root.expandAnimationEnabled && root.resizeAnimationEnabled
        NumberAnimation{
            duration: 120
            easing.type: Easing.InOutQuad
        }
    }

    function startExpandAnimation(){
        if(!root.expandAnimationEnabled || expandAnimation.running)return
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
                to: root.height
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [1.00, 0.00, 0.40, 1.33,1,1]
                onFinished: {
                    root.expandAnimationEnabled = false
                }
            }
        Component.onCompleted: {
            if(root.expandAnimationEnabled && !root.deferInitialExpand)
                root.startExpandAnimation()
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
