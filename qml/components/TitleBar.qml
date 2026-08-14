import QtQuick
//import QtQuick.Window
import xcshop


Rectangle {
    id: root
    property bool showControls: true
    property Window mainWindow
    property int margins: root.mainWindow.visibility === Window.Maximized? 0 : Constants.margins
    property bool colorFilling: true
    
    signal closeClicked()
    signal maximizeClicked()
    signal minimizeClicked()
    
    x: root.margins
    y: root.margins
    width: parent.width - root.margins * 2
    height: 36

    color: colorFilling? Colors.background_n : Colors.transparent

    Behavior on color{
        ColorAnimation{
            duration: 200
        }
    }


    XCText{
        id: titleText
        x:8
        xcText: "【小菜粽子】UI商店生成器"
        xcFontSize: 16
    }
    
    MouseArea {
        anchors.fill: parent
        onPressed: root.mainWindow.startSystemMove()    //窗口拖动
        onReleased: {
            if (mapToGlobal(mouseX,mouseY).y <= 10){    //快捷最大化(拖到屏幕最上方)
                root.mainWindow.showFullScreen()
                root.mainWindow.showMaximized()
            }
        }
        onDoubleClicked:    //双击最大化
            if(root.mainWindow.visibility === Window.Maximized){
                root.mainWindow.showFullScreen()
                root.mainWindow.showNormal()
            }else{
                root.mainWindow.showFullScreen()
                root.mainWindow.showMaximized()
            }
    }
    
    Row {
        id: btnRow
        
        //最小化时，控制按钮的大小为30，否则为36，以便于最小化时的美观以及 最大化时能使按钮紧贴屏幕边缘
        property int ctrBtnSize : root.mainWindow.visibility === Window.Maximized ? 
            36 : 30

        x: root.mainWindow.width - 2*root.margins - btnRow.width - (36-ctrBtnSize)/2     //为了配合按钮的大小，设置按钮与窗口右侧的距离（3或0）
        anchors.verticalCenter: parent.verticalCenter         //按钮垂直居中
        spacing: 0
        visible: root.showControls
        
        ImageButton {
            id: minimizeBtn
            btnSize: btnRow.ctrBtnSize
            btnRadius: 2
            //最小化按钮
            imageSource: "qrc:/assets/gui/titleBar/minimize.png"
            onClicked: root.minimizeClicked()
        }
        
        ImageButton {
            id: maximizeBtn
            btnSize: btnRow.ctrBtnSize
            btnRadius: 2
            //最大化/恢复按钮图标切换
            imageSource: root.mainWindow.visibility === Window.Maximized ?
                "qrc:/assets/gui/titleBar/restore.png" : "qrc:/assets/gui/titleBar/maximize.png"
            onClicked: root.maximizeClicked()
        }
        
        ImageButton {
            id: closeBtn
            btnSize: btnRow.ctrBtnSize
            btnRadius: 2
            topRightRadius: root.mainWindow.visibility === Window.Maximized ? 2 : Constants.window_radius - 2
            btnfired: "#FF0000"
            btnpressed: "#a00c0c"
            //关闭按钮
            imageSource: "qrc:/assets/gui/titleBar/close.png"
            onClicked: root.closeClicked()
        }
    }
}
