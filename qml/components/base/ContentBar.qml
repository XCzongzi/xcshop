import QtQuick
import xcshop


FocusScope{
    id: root

    property bool delayExpand: false
    property int padding: 16

    property int min_width: -1
    property bool expanded: false  //展开动画播放完毕后，此项将设为真。若此项初始时便为真，则意为取消动画
    property int contentHeight
    property string title: ""
    property string subtitle: ""
    property alias color: surface.color
    width: parent.layout ? parent.contentWidthEnhance + min_width : parent.width - 32
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

    ContentSurface {
        id: surface
        hoverEffectsEnabled: true
        hoverTarget: root
        anchors.fill: root
        XCText{
            id: itemInput_propertyText
            y: 18
            x: root.padding
            width: parent.width - root.padding * 2
            xcText: root.title
            xcFontSize: 18
            onCenter: false
            elide: Text.ElideRight
        }
        XCText{
            x: root.padding
            y: 46
            width: parent.width - root.padding * 2
            xcText: root.subtitle
            xcFontSize: 12
            onCenter: false
            boldFont: false
            textColor: Colors.banned
            elide: Text.ElideMiddle
        }
        

        //展开动画（创建时）
            NumberAnimation{
                id: expandAnimation
                target: root
                property: "height"
                from: 0
                to: root.contentHeight
                duration: 420 / Global.animationSpeed
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


        MouseArea{
            anchors.fill: parent
            onClicked: forceActiveFocus(root)
        }
    }

}
