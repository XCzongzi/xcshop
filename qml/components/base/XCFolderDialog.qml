import QtQuick
import QtQuick.Dialogs
import xcshop


FolderDialog{
    id: root

    property string dialogID: ""
    

    title: "选择一个文件夹："
    XCFile { id: paths }

    function openXC(dID,location){
        root.dialogID = dID
        root.currentFolder = paths.dialogFolderUrl(location || "")
        root.open()
    }

}
