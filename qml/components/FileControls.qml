import QtQuick
import xcshop

Rectangle {
    id: root
    width: parent.width - x
    height: editableElement ? 106 : 78
    color: Colors.foreground

    readonly property bool editableElement: Global.current_element !== "Total"
    readonly property bool elementSelected: Global.get_fileName().length > 0
    readonly property string pageEyebrow: {
        switch (Global.current_element) {
        case "UI": return "UI EDITOR"
        case "Item": return "ITEM EDITOR"
        case "Cost": return "COST EDITOR"
        case "Display": return "DISPLAY EDITOR"
        default: return "PROJECT OVERVIEW"
        }
    }
    readonly property string pageTitle: {
        switch (Global.current_element) {
        case "UI": return "界面编辑"
        case "Item": return "物品编辑"
        case "Cost": return "代价设置"
        case "Display": return "展示格式"
        default: return "项目总览"
        }
    }
    readonly property string pageSubtitle: {
        switch (Global.current_element) {
        case "UI": return "选择一个 UI 文件，编辑商店界面内容。"
        case "Item": return "维护物品标识、展示信息以及触发规则。"
        case "Cost": return "配置商品购买时所需的资源与显示名称。"
        case "Display": return "定义商店代价的文本结构与展示顺序。"
        default: return "查看当前项目概览，并从左侧切换对应的编辑区域。"
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Colors.changeA(Colors.text, 0.10)
    }

    Rectangle {
        x: 20
        y: 15
        width: 3
        height: root.editableElement ? 36 : 48
        radius: 2
        color: Colors.border
    }

    Column {
        x: 34
        y: 12
        spacing: 2

        XCText { xcText: root.pageEyebrow; onCenter: false; xcFontSize: 10; textColor: Colors.border }
        XCText { xcText: root.pageTitle; onCenter: false; xcFontSize: 21 }
        XCText {
            visible: !root.editableElement
            xcText: root.pageSubtitle
            onCenter: false
            xcFontSize: 12
            boldFont: false
            textColor: Colors.banned
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: root.editableElement ? 17 : 27
        width: projectState.width + 20
        height: 24
        radius: 12
        color: Colors.changeA(Colors.border, 0.17)
        border.width: 1
        border.color: Colors.changeA(Colors.border, 0.36)
        XCText {
            id: projectState
            anchors.centerIn: parent
            xcText: root.editableElement && !root.elementSelected ? "请选择元素" : "已连接项目"
            xcFontSize: 11
            boldFont: false
            textColor: Colors.border
        }
    }

    Item {
        visible: root.editableElement
        x: 20
        y: 53
        width: parent.width - 40
        height: 48

        TextButton {
            id: deleteFile
            anchors.verticalCenter: parent.verticalCenter
            text: "删除"
            enabled: root.elementSelected
            textSize: 12
            height: 30
            widthBorderSize: 10
            radius: 6
            buttonColor: Colors.changeA(Colors.error, 0.70)
            firedColor: Colors.changeA(Colors.error, 0.88)
            pressedColor: Colors.error
            onClicked: Global.file_delete()
        }
        TextButton {
            id: cloneFile
            x: deleteFile.width + 8
            anchors.verticalCenter: parent.verticalCenter
            text: "克隆"
            enabled: root.elementSelected
            textSize: 12
            height: 30
            widthBorderSize: 10
            radius: 6
            buttonColor: Colors.changeA(Colors.pressed, 0.90)
            firedColor: Colors.changeA(Colors.fired, 0.96)
            pressedColor: Colors.changeA(Colors.border, 0.60)
            onClicked: Global.file_clone()
        }
        Rectangle {
            x: cloneFile.x + cloneFile.width + 14
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 28
            color: Colors.changeA(Colors.text, 0.10)
        }
        XCKeyInput {
            id: elementName
            x: cloneFile.x + cloneFile.width + 30
            width: Math.max(180, parent.width - x)
            anchors.verticalCenter: parent.verticalCenter
            enabled: root.elementSelected
            autoSaveType: 1
            keyText: "元素名称"
            fieldText: "未选择元素"
            Component.onCompleted: SignalBus.elementNameReturn.connect(setContext)
        }
    }
}
