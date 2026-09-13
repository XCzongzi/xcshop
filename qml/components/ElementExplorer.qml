import QtQuick
import xcshop


Rectangle{
    property int barWidth
    property bool isShowing: false
    property string pendingFolder: ""
    id: root
    // 当前元素类型是否已有选中的文件。保持绑定，避免在其它类型打开
    // 文件后，切到尚未选择文件的类型时沿用旧的 true 状态。
    readonly property bool started: Global.get_fileName().length > 0
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
        // 切换元素类型时回到当前文件所在目录，使打开状态标记保持可见。
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
    }

    Timer{       //似乎Global.current_element和xcFileTree.currentFolder一起改变的话会出问题，所以这边用Timer防止出问题
        id: timer
        interval: 1
        onTriggered:{
            xcFileTree.currentFolder = root.pendingFolder
            root.pendingFolder = ""
            if(Global.current_element != "Total")treeAnim.start()
        }
        
    }
    NumberAnimation{
        id: treeAnim
        target: root
        property: "contentOpacity"
        duration: 120 / Global.animationSpeed
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
            // Scale spring and damping together so the panel keeps its
            // original elastic response while its settling time follows the
            // configured animation speed.
            spring: 1.5 * Global.animationSpeed * Global.animationSpeed
            damping: 0.2 * Global.animationSpeed
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
        onElementPathsDropped: function(paths) {
            xcFileTree.moveEntriesToParentDirectory(paths)
        }
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
    }
}
