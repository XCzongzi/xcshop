import QtQuick
import QtQuick.Dialogs


FolderDialog{
    id: root

    property string dialogID: ""
    

    title: "选择一个文件夹："

    function openXC(dID,location){
        root.dialogID = dID
        root.currentFolder = "file:" + location
        root.open()
    }

}