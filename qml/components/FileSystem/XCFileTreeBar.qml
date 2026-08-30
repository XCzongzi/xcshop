pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import xcshop

Item{
    id:root
    //anchors.fill: parent
    
    property string currentFolder: ""
    property string filePath: "file:" + Global.project_location + "/" + Global.current_element + currentFolder
    property int selectionRetryCount: 0

    signal floderSwitched()
    signal fileSwitched()

    function directionBack(){
        currentFolder = currentFolder.split('/').slice(0, -1).join('/')
        root.floderSwitched()
    }
    Component.onCompleted:{
        SignalBus.elementIndexReset.connect(set_selection)
    }
    function refreshCurrentSelectionLater(){
        var fileLocation = Global.get_fileLocation(true)
        var fileName = Global.get_fileName()
        selectionRetryCount = 0
        Qt.callLater(function(){
            root.refreshSelection(fileLocation, fileName)
        })
    }
    function refreshSelection(fileLocation, fileName){
        //Console.output(filePath + "\n" + fileLocation)
        if(filePath !== fileLocation)
            return

        // 延后/重试期间可能又打开了另一份文件，旧请求不得覆盖新选择。
        if(Global.get_fileLocation(true) !== fileLocation || Global.get_fileName() !== fileName)
            return

        if(!fileName.length)
            return

        var selectionIndex = get_index(fileName)
        var selectedItem = selectionIndex >= 0 ? fileList.itemAtIndex(selectionIndex) : null
        if(!selectedItem){
            // FolderListModel Ready 时，ListView 的 delegate 可能仍未创建完成。
            // 在下一帧重试几次，避免首次跨类型打开时漏掉高亮。
            if(selectionRetryCount < 5){
                ++selectionRetryCount
                selectionRetryTimer.fileLocation = fileLocation
                selectionRetryTimer.fileName = fileName
                selectionRetryTimer.restart()
            }
            return
        }

        // 清除旧文件的高亮，保证元素管理器始终只有一个当前文件。
        for(var i = 0; i < fileList.count; ++i){
            var item = fileList.itemAtIndex(i)
            if(item)
                item.setSelection(false, true)
        }

        selectedItem.setSelection(true, true)
        selectionRetryCount = 0
    }
    function get_index(fileName){
        for(var i = 0; i < folderFileModel.count; i++){
            //Console.output(folderFileModel.get(i,"fileBaseName"))
            //Console.output(fileName)
            if(folderFileModel.get(i,"fileBaseName") == fileName){
                return i
            }
        }
        return -1
    }
    Timer{
        id: selectionRetryTimer
        interval: 16
        property string fileLocation: ""
        property string fileName: ""
        onTriggered: root.refreshSelection(fileLocation, fileName)
    }
    // Timer{      //用Timer启动刷新，因为文件系统的变化可能有延迟
    //     id: refreshTimer
    //     interval: 1
    //     onTriggered: {
    //         root.refreshSelection(Global.get_fileLocation(true), Global.get_fileName())
    //     }
    // }//-------------//--------------------
    function set_selection(selectionIndex){
        indexResetTimer.selectionIndex = selectionIndex
        indexResetTimer.start()
        Console.output("selectionIndex")
    }
    Timer{  //这个timer须与refresh的timer间隔时间不同
        id:indexResetTimer
        interval: 18
        property int selectionIndex
        onTriggered: {
            Console.output(selectionIndex + " " + folderFileModel.count)
            if(selectionIndex > folderFileModel.count - 1){
                Global.set_file("*","")
            }else{
                fileList.itemAtIndex(selectionIndex).setSelection(true,true)
                Global.set_file("*",folderFileModel.get(selectionIndex,"fileBaseName"))
            }
            root.fileSwitched()
        }
    }//----------------------

    onFilePathChanged:{
        //Global.set_file(root.currentFolder,"")
        //refreshTimer.start()
        root.fileSwitched()
        root.refreshCurrentSelectionLater()
    }
    

    // 文件列表模型
    FolderListModel {
        id: folderFileModel
        folder: Qt.resolvedUrl(root.filePath)
        showDirs: false
        showFiles: true      // 仅显示文件
        //showDotAndDotDot: false
        showHidden: false    // 不显示隐藏文件
        nameFilters: ["*.xcse" + Global.current_element]
        onStatusChanged: {
            
            if(folderFileModel.status == FolderListModel.Ready){
                Console.output("onStatusChanged: " + status)
                // 触发这两个flick方法是为了让ListView刷新
                fileList.flick(0,1)
                direList.flick(0,1)
                // Ready 只表示模型数据可用；delegate 仍可能在本轮事件循环内创建。
                root.refreshCurrentSelectionLater()
                

            }
        }
    }
    FolderListModel {
        id: folderDireModel
        folder: Qt.resolvedUrl(root.filePath)
        showDirs: true     // 仅显示子文件夹
        showFiles: false
        //showDotAndDotDot: false
        showHidden: false    // 不显示隐藏文件
        //nameFilters: ["*.xcse" + Global.current_element]
    }
    
    
    Flickable{      //用一个Flickable嵌套两个ListView，把文件与文件夹隔开
        id:flickable
        height: parent.height
        width: flickable.contentHeight <= flickable.height? parent.width : (parent.width - 7)   //适应滚动条
        clip: true
        contentHeight: direList.contentHeight + fileList.contentHeight
            ListView{       //文件夹列表
                id: direList
                height:contentHeight
                width:parent.width
    
                clip: true
                interactive:false
    
                model:folderDireModel
                delegate: FileButton{
                    required property var model
                    text:model.fileBaseName
                    width: parent.width
                    height: 24
                    icon:"File"
                    onClicked:{
                        root.currentFolder += "/" + model.fileBaseName
                        root.floderSwitched()
                    }
                }
            }
            ListView{       //文件列表
                y:direList.y+direList.height
                id: fileList
                height:contentHeight
                width:parent.width
        
                clip: true
                interactive:false
        
                model:folderFileModel
                delegate: FileButton{
                    required property var model
                    text:model.fileBaseName
                    width: parent.width
                    height: 24
                    icon:Global.current_element
                    onClicked:{
                        Global.set_file(root.currentFolder,text)
                        for(var i = 0; i < fileList.count; i++) {
                            fileList.itemAtIndex(i).setSelection(false)
                        }
                        setSelection(true)
                        Global.current_file_index = model.index
                        root.fileSwitched()
                        SignalBus.elementOpened(Global.current_element, Global.get_filePath(), text)
                        SignalBus.sendToMain("switched_file",{})
                    }
                }
            }
        
    }



    Rectangle{      //滚动条
        visible: flickable.contentHeight <= flickable.height? false : true
        id: scrollerBar
        x: parent.width - 6
        width: 5
        height: parent.height
        color: Colors.transparent

        Rectangle{
            id: scrollerHandle
            width: 5
            height:Math.max(30,flickable.height/(flickable.contentHeight/flickable.height))
            //radius: 3
            color: "gray"
            Behavior on color {
                ColorAnimation {
                duration: 500
                easing.type: Easing.InOutQuad
                }
            }
            property bool scrollerEnabled: false    //防止flickable的丝滑动画被顶掉
            MouseArea {
                anchors.fill: parent
                drag.target: scrollerHandle
                drag.axis: Drag.YAxis
                drag.minimumY: 0
                drag.maximumY: scrollerBar.height - scrollerHandle.height
                hoverEnabled: true
                property bool pressed: false
                onEntered: {
                    scrollerHandle.color = Qt.darker("white",1.2)
                }
                onExited: {
                    scrollerHandle.color = pressed? "white" : "gray"
                }
                onPressed: {
                    scrollerHandle.color = "white"
                    pressed = true
                    scrollerHandle.scrollerEnabled = true
                }
                onReleased: {
                    scrollerHandle.color = containsMouse? Qt.darker("white",1.2) : "gray"
                    pressed = false
                    scrollerHandle.scrollerEnabled = false
                }
            }
            onYChanged: {
                if(scrollerEnabled){
                    flickable.contentY = scrollerHandle.y * (flickable.contentHeight - flickable.height) / (scrollerBar.height - scrollerHandle.height)
                }
                
            }
        }
        Binding {
        target: scrollerHandle
        property: "y"
        value: flickable.contentY * (scrollerBar.height - scrollerHandle.height) / (flickable.contentHeight - flickable.height)
        }
        
    }

}
