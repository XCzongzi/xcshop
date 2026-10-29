import QtQuick
import xcshop


PanelSurface{
    property int barWidth
    property bool isShowing: false
    property string pendingFolder: ""
    id: root
    // 当前元素类型是否已有选中的文件。保持绑定，避免在其它类型打开
    // 文件后，切到尚未选择文件的类型时沿用旧的 true 状态。
    readonly property bool started: Global.get_fileName().length > 0
    readonly property bool canLocateCurrentElement: started && Global.parseElementPath(Global.get_filePath()) !== null
    width: isShowing ? barWidth : 0
    height: parent.height
    x: Constants.typeBarWidth
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
        var element = Global.parseElementPath(Global.get_filePath())
        return element ? element.folder : ""
    }
    function locateCurrentElement(){
        if (!canLocateCurrentElement)
            return
        barShow()
        openElementFolder(currentElementFolder())
    }
    function openElementFolder(folder){
        timer.stop()
        pendingFolder = ""
        xcFileTree.currentFolder = folder || ""
        xcFileTree.finishOperation()
        root.floderSwitch()
    }

    Timer{       //似乎Global.current_element和xcFileTree.currentFolder一起改变的话会出问题，所以这边用Timer防止出问题
        id: timer
        interval: 1
        onTriggered:{
            xcFileTree.currentFolder = root.pendingFolder
            root.pendingFolder = ""
            if(Global.current_element != "Global")treeAnim.start()
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
                                     Math.min(Global.window_width / 2 - 32,
                                              pressWidth + delta))
        }
        onDragFinished: {
            widthAnim.enabled = true
            Global.saveElementExplorerWidth(root.barWidth)
        }
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
        id: fileCtrlBar
        objectName: "explorerFileControls"
        z: 2
        height: 32
        width:root.width - 3
        onBackbtnClicked: xcFileTree.directionBack()
        onCreationFinished: xcFileTree.finishOperation()
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
        color: Colors.isLight ? Colors.outline : Qt.lighter("gray",1.5)
    }

    XCText{
        id:xcPathText
        objectName: "explorerDirectoryPath"
        x: 5
        y: 36
        xcText: "project:/" + Global.current_element + xcFileTree.currentFolder
        xcFontSize: 12
        onCenter:false
        width: parent.width - x - 3
        elide: Text.ElideLeft
        textColor: Colors.isLight ? Colors.banned : Qt.lighter("gray",1.5)
        opacity: root.contentOpacity
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: function(mouse) {
                SignalBus.contextMenuRequested(xcPathText, mouse.x, mouse.y, [
                    { "text": "回到当前编辑的元素位置",
                      "enabled": root.canLocateCurrentElement,
                      "action": function() { root.locateCurrentElement() } }
                ], null)
            }
        }
    }
    
    XCFileTreeBar{
        id:xcFileTree
        objectName: "explorerFileTree"
        width: root.width - 3
        y:xcPathText.y + xcPathText.height + 2
        height: root.height - y - 2
        opacity: root.contentOpacity
        onCreateEntryRequested: function(isFolder) { fileCtrlBar.requestCreate(isFolder) }
        onFloderSwitched:{
            root.floderSwitch()
        }
    }
}
