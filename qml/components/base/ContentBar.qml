import QtQuick
import xcshop


FocusScope{
    id: root

    property bool delayExpand: false
    property int padding: 16

    property int min_width: -1
    property bool expanded: false  //展开动画播放完毕后，此项将设为真。若此项初始时便为真，则意为取消动画
    property real expansionProgress: 0
    property int contentHeight
    property string title: ""
    property string subtitle: ""
    property alias color: surface.color
    width: parent.layout ? parent.contentWidthEnhance + min_width : parent.width - 32
    // 内容的布局可能在动画开始后才完成，始终用最新高度计算展开尺寸。
    height: root.contentHeight * (root.expanded ? 1 : root.expansionProgress)
    clip: true
    enabled: height > 0

    function expand(){
        if (!root.expanded)
            expandAnimation.start()
    }

    NumberAnimation {
        id: expandAnimation
        target: root
        property: "expansionProgress"
        from: 0
        to: 1
        duration: 420 / Global.animationSpeed
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [1.00, 0.00, 0.40, 1.33,1,1]
        onFinished: root.expanded = true
    }
    Component.onCompleted: {
        if (!root.delayExpand && !root.expanded)
            root.expand()
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
        

        MouseArea{
            anchors.fill: parent
            onClicked: forceActiveFocus(root)
        }
    }

}
