pragma Singleton
import QtQuick

QtObject{

    //主模块信号：用于在Main.qml中接收任意位置发送的信号
    signal sendToMain(string signalType , var parameters)

    // 全局右键菜单：target 为触发控件，x/y 为其局部坐标。
    signal contextMenuRequested(var target, real x, real y, var items,
                                var contentComponent)
    signal contextMenuCloseRequested()
    signal contextMenuClosed()

    //“选择元素”组件与元素中转区之间的通信接口
    signal elementSelectionRequested(string selectionId)
    signal elementSelectionCancelled(string selectionId)
    signal elementSelectionResolved(string filePath)
    signal elementDragStateChanged(bool active)
    property string draggedElementPath: ""
    property var draggedElementPaths: []
    signal elementSelectionRequestActivated(var selectionItem)
    signal elementSelectionFocusChanged(bool active, var sceneRect)

    signal elementSelectionDeselect()//点击遮罩空白处时，发送取消选择的信号到“选择元素”

    //元素管理器与元素中转区
    signal elementOpened(string elementType, string filePath, string elementName)
    // 元素文件成功写入后通知依赖其固定属性的预览重新读取文件。
    signal elementDataSaved(string elementType, string filePath)
    signal elementOpenRequested(string filePath)
    signal elementsAddToRelayRequested(var filePaths, string groupKey)
    signal elementFilesMoved(var moves)
    signal elementFilesDeleted(var filePaths)



}
