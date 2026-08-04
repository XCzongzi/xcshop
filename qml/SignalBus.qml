pragma Singleton
import QtQuick

QtObject{

    //主模块信号：用于在Main.qml中接收任意位置发送的信号
    signal sendToMain(string signalType , var parameters)

    //元素名返回
    signal elementNameReturn(string text)

    //重新设置元素管理器的index
    signal elementIndexReset(int index)

    //“选择元素”组件与元素中转区之间的通信接口
    signal elementSelectionRequested(string selectionId)
    signal elementSelectionCancelled(string selectionId)
    signal elementSelectionResolved(string filePath)
    signal elementDragStateChanged(bool active)
    property string draggedElementPath: ""
    signal elementSelectionRequestActivated(var selectionItem)
    signal elementSelectionFocusChanged(bool active, var sceneRect)

    signal elementSelectionDeselect()//点击遮罩空白处时，发送取消选择的信号到“选择元素”

    //元素管理器与元素中转区
    signal elementOpened(string elementType, string filePath, string elementName)



}
