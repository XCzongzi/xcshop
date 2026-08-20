import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    workspace: true

    property int pageMargin: 20
    property int cardGap: 12

    ContentBar {
        id: projectSummary
        x: root.pageMargin
        y: 16
        width: parent.width - root.pageMargin * 2
        contentHeight: 116
        expanded: true

        XCText { x: 20; y: 18; xcText: "当前项目"; onCenter: false; xcFontSize: 17 }
        XCText {
            x: 20
            y: 48
            width: parent.width - 40
            xcText: Global.project_location.length ? Global.project_location : "尚未选择项目"
            onCenter: false
            xcFontSize: 13
            boldFont: false
            textColor: Colors.banned
            elide: Text.ElideMiddle
        }
        Rectangle {
            x: 20
            y: 82
            width: parent.width - 40
            height: 1
            color: Colors.changeA(Colors.text, 0.09)
        }
        XCText {
            x: 20
            y: 91
            xcText: "使用左侧导航切换 UI、物品、代价和展示内容。"
            onCenter: false
            xcFontSize: 11
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.58)
        }
    }

    
}
