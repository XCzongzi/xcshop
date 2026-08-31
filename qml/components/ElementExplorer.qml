import QtQuick
import xcshop


Rectangle{
    property int barWidth
    property bool isShowing: false
    property string currentFilePath: ""
    property string pendingFolder: ""
    id: root
    property bool started: Global.get_fileName() != ""
    width: isShowing ? barWidth : 0
    height: parent.height
    x:65
    color: Colors.foreground
    clip: true
    enabled: isShowing


    property double contentOpacity: 1
    function floderSwitch(){
        root.contentOpacity = 0
        treeAnim.start()
    }
    function floderReset(){
        // 切换元素类型时，回到该类型当前文件所在的目录；否则文件列表在根目录，
        // 即使 Global 中已有当前文件，也无法在列表里选中它。
        if (!root.pendingFolder.length)
            root.pendingFolder = root.currentElementFolder()
        root.contentOpacity = 0
        timer.start()
    }
    function currentElementFolder(){
        var typeRoot = Global.project_location + "/" + Global.current_element
        var fileLocation = Global.get_fileLocation(false)
        return fileLocation.indexOf(typeRoot) === 0
                ? fileLocation.substring(typeRoot.length)
                : ""
    }
    function openElementFolder(folder){
        pendingFolder = ""
        xcFileTree.currentFolder = folder || ""
        root.floderSwitch()
        // 同目录内切换文件不会触发 FolderListModel 的重新加载，因此需要主动刷新选中态。
        xcFileTree.refreshCurrentSelectionLater()
    }

    Timer{       //似乎Global.current_element和xcFileTree.currentFolder一起改变的话会出问题，所以这边用Timer防止出问题
        id: timer
        interval: 1
        onTriggered:{
            xcFileTree.currentFolder = root.pendingFolder
            root.pendingFolder = ""
            if(Global.current_element != "Total")treeAnim.start()
            xcFileTree.refreshCurrentSelectionLater()
        }
        
    }
    NumberAnimation{
        id: treeAnim
        target: root
        property: "contentOpacity"
        duration: 120
        to: 1
    }

    ResizeHandle {
        id: resizeHandle
        visible: root.isShowing
        z: 10
        x: root.width - width / 2
        width: 12
        height: parent.height

        property int pressWidth: 0

        onDragStarted: {
            widthAnim.enabled = false
            pressWidth = root.barWidth
        }
        onDragMoved: function(delta) {
            root.barWidth = Math.max(150,
                                     Math.min(Global.window_width - 100,
                                              pressWidth + delta))
        }
        onDragFinished: widthAnim.enabled = true
        onDragCanceled: widthAnim.enabled = true
    }
    

    Behavior on width { 
        id: widthAnim
        enabled: false
        SpringAnimation { 
            spring: 1.5
            damping: 0.2 
            epsilon: 0.01
        } 
    }


   function barShow(animation = true){
        widthAnim.enabled = animation
        isShowing = true
   }
   function barHide(animation = true){
        widthAnim.enabled = animation
        isShowing = false
   }


    FileCtrlBar{
        z: 2
        height: 32
        width:root.width - 3
        onBackbtnClicked: xcFileTree.directionBack()
        hideBackBtn: !xcFileTree.currentFolder
        filePath: Global.project_location + "/" + Global.current_element + xcFileTree.currentFolder
    }

    Rectangle{
        x: 3
        y: 32
        width: root.width - 9
        height: 1
        color: Qt.lighter("gray",1.5)
    }

    XCText{
        id:xcPathText
        x: 5
        y: 36
        xcText: "project:/" + Global.current_element + xcFileTree.currentFolder
        xcFontSize: 12
        onCenter:false
        width: parent.width - x - 3
        elide: Text.ElideLeft
        textColor: Qt.lighter("gray",1.5)
        opacity: root.contentOpacity
    }
    
    XCFileTreeBar{
        id:xcFileTree
        width: root.width - 3
        y:xcPathText.y + xcPathText.height + 2
        height: root.height - y - 2
        opacity: root.contentOpacity
        onFloderSwitched:{
            root.floderSwitch()
        }
        onFileSwitched:{
            root.started = Global.get_fileName() != ""
        }
    }
}
