import QtQuick
import QtQuick.Dialogs
import xcshop


FileDialog{
    id: root

    property bool isSave: false
    property string dialogID: ""
    fileMode: isSave? FileDialog.SaveFile : FileDialog.OpenFile
    


    title: isSave? "选择存储位置" : "选择文件"
    XCFile { id: paths }

    function openXC(is_save,dID,location){
        root.dialogID = dID
        root.isSave = is_save
        if (location !== undefined)
            root.currentFolder = paths.dialogFolderUrl(location)
        root.open()
    }

}
