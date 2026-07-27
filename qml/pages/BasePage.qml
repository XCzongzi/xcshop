import QtQuick

Rectangle{
    id: root
    property Window mainWindow
    property bool layout: false                                     //用于决定布局是否自适应窗口大小而改变
    property int content_height: 0                                  //用于记录内容高度，以便滚动条的高度变化
    readonly property int height_output: scrollBar.height_output    //用于输出滚动条已滚动的高度
    property bool fullScreen: false                                 //用于记录是否全屏显示，一般只在开始界面为true
    property bool workspace: false                                  //是否显示诸如元素管理器、文件管理等功能界面，用于区分全屏界面与工作区界面;同时作为标记界面是否更改窗口底色为base主题色
                                                                    

    signal pageEvent(string signalType, var parameters)    //通过一个总信号+类型参数来传递信号到Main.qml的Connections中

    function executeFromMain(type,parameters){}
    function setScrollOffset(offset){ scrollBar.setContentOffset(offset) }

    x: fullScreen? -65 : 0
    color: "black"
    clip: true
    bottomLeftRadius: Constants.window_radius
    bottomRightRadius: Constants.window_radius
    

    //动画/创建
    opacity: 0
    enabled: opacity > 0.01
    Behavior on opacity {
        NumberAnimation{
            duration: 500
        }
    }
    Component.onCompleted: {
        SignalBus.elementNameReturn(Global.get_fileName())
        root.opacity = 1
    }

    //滚动条
    WheelHandler{
        rotationScale: 0.1
        onWheel: function(event) {
            scrollBar.wheelDeltaY = event.angleDelta.y
            scrollBar.wheel()
        }
    }
    ScrollBar{
        id: scrollBar
        layout_determines: root.layout
        content_height: root.content_height
    }
}
