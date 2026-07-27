import QtQuick
import QtQuick.Dialogs


FileDialog{
    id: root

    property bool isSave: false
    property bool isFloder: false
    property string dialogID: ""
    fileMode: isSave? FileDialog.SaveFile : FileDialog.OpenFile
    


    title: isSave? "选择存储位置" : "选择文件"

    function openXC(is_save,dID){
        root.dialogID = dID
        root.isSave = is_save
        root.open()
    }

}