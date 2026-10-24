import QtQuick
import xcshop

BasePage{
    id: root

    property var eledata: ({})
    property bool dataLoaded: false
    property string dataError: ""

    ElementIO{
        id:eio
    }
    Component.onCompleted:{
        var filePath = Global.get_filePath()
        dataLoaded = false
        dataError = ""

        if (!eio.open(filePath)) {
            dataError = "无法打开元素文件：" + filePath
            console.warn(dataError)
            return
        }

        try {
            var serialized = eio.read()
            var parsed = !serialized.trim().length && Global.current_element === "UI"
                    ? ({}) : JSON.parse(serialized)
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                throw new Error("元素文件根节点必须是对象")
            root.eledata = parsed
            dataLoaded = true
            elementReading()
        } catch (error) {
            dataLoaded = false
            dataError = "无法读取元素文件：" + filePath + "（" + error + "）"
            console.warn(dataError)
        }
    }
    function updateDataOut(){
        if (!dataLoaded)
            return false

        var serialized
        try {
            serialized = JSON.stringify(storageData())
        } catch (error) {
            dataError = "无法序列化元素数据：" + error
            console.warn(dataError)
            return false
        }

        if (serialized === undefined) {
            dataError = "无法序列化元素数据"
            console.warn(dataError)
            return false
        }

        if (!eio.write(serialized)) {
            dataError = "无法保存元素文件：" + Global.get_filePath()
            console.warn(dataError)
            return false
        }

        SignalBus.elementDataSaved(Global.current_element, Global.get_filePath())
        dataError = ""
        return true

    }
    function storageData(){ return eledata }
    function elementReading(){}
    
}
