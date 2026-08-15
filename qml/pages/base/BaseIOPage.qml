import QtQuick
import xcshop

BasePage{
    id: root

    property var eledata: ({})

    ElementIO{
        id:eio
    }
    Component.onCompleted:{
        eio.open(Global.get_filePath())
        root.eledata = JSON.parse(eio.read())

        elementReading()
    }
    function updateDataOut(){

        eio.write(JSON.stringify(eledata))

    }
    function elementReading(){}
    
}