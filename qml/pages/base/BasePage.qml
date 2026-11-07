import QtQuick
import xcshop

Rectangle{
    id: root
    property Window mainWindow
    // Page-owned background decorations can join the real window backdrop.
    property Item backgroundHost: null
    property bool usePageScrollBar: true // 自带 Flickable 的页面可关闭旧滚动逻辑。
    property bool layout: headContentMinWidth + 16*(maxHeadContentCount + 1) < width //用于决定布局是否自适应窗口大小而改变
    property int content_height: 0                                  //用于记录内容高度，以便滚动条的高度变化
    readonly property int height_output: scrollBar.height_output    //用于输出滚动条已滚动的高度
    property bool fullScreen: false                                 //用于记录是否全屏显示，一般只在开始界面为true
    property bool workspace: false                                  //是否显示诸如元素管理器、文件管理等功能界面，用于区分全屏界面与工作区界面;同时作为标记界面是否更改窗口底色为base主题色

    property int maxHeadContentCount:1                              //头内容的最大数，记录了窗口最大可出现的ContentBar列数
    property int headContentMinWidth                                //头内容最小宽度，记录窗口最大状态下，将出现在第一行的所有ContentBar的总宽度与其之间的空隙和
    readonly property int contentWidthEnhance: layout? (width - headContentMinWidth - 16*(maxHeadContentCount + 1)) / maxHeadContentCount : 0
    //宽度增强，用于适应布局。根据headContentWidth变量自动为ContentBar计算额外的宽度补偿，以适应窗口的宽度变化                                                         

    signal pageEvent(string signalType, var parameters)    //通过一个总信号+类型参数来传递信号到Main.qml的Connections中

    function executeFromMain(type,parameters){}
    function setScrollOffset(offset){ scrollBar.setContentOffset(offset) }

    x: fullScreen? -Constants.typeBarWidth : 0
    color: "black"
    clip: true
    bottomLeftRadius: Constants.window_radius
    bottomRightRadius: Constants.window_radius
    

    property bool animateEntrance: true
    opacity: animateEntrance ? 0 : 1
    enabled: opacity > 0.01
    onAnimateEntranceChanged: {
        if (!animateEntrance && entranceBehavior) {
            entranceBehavior.enabled = false
            opacity = 1
        }
    }
    Behavior on opacity {
        id: entranceBehavior
        enabled: root.animateEntrance
        NumberAnimation {
            duration: 500 / Global.animationSpeed
        }
    }
    Component.onCompleted: root.opacity = 1

    //滚动条
    WheelHandler{
        enabled: root.usePageScrollBar
        rotationScale: 0.1
        onWheel: function(event) {
            scrollBar.wheelDeltaY = event.angleDelta.y
            scrollBar.wheel()
        }
    }
    ScrollBar{
        id: scrollBar
        visible: root.usePageScrollBar && content_height > height
        layout_determines: root.layout
        content_height: root.content_height
    }
}
