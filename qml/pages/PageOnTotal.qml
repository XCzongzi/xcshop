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
        height: 116

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

    Row {
        id: overviewCards
        x: root.pageMargin
        y: projectSummary.y + projectSummary.height + root.cardGap
        width: parent.width - root.pageMargin * 2
        spacing: root.cardGap

        ContentBar {
            width: (overviewCards.width - overviewCards.spacing * 2) / 3
            height: 142
            XCText { x: 18; y: 18; xcText: "界面配置"; onCenter: false; xcFontSize: 16 }
            XCText { x: 18; y: 51; xcText: "UI"; onCenter: false; xcFontSize: 28; textColor: Colors.border }
            XCText { x: 18; y: 94; width: parent.width - 36; xcText: "从左侧文件树选择界面文件进行编辑。"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned; xcWrapMode: true }
        }
        ContentBar {
            width: (overviewCards.width - overviewCards.spacing * 2) / 3
            height: 142
            XCText { x: 18; y: 18; xcText: "商品元素"; onCenter: false; xcFontSize: 16 }
            XCText { x: 18; y: 51; xcText: "ITEM"; onCenter: false; xcFontSize: 28; textColor: Colors.border }
            XCText { x: 18; y: 94; width: parent.width - 36; xcText: "维护物品标识、展示信息与触发规则。"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned; xcWrapMode: true }
        }
        ContentBar {
            width: (overviewCards.width - overviewCards.spacing * 2) / 3
            height: 142
            XCText { x: 18; y: 18; xcText: "构建与展示"; onCenter: false; xcFontSize: 16 }
            XCText { x: 18; y: 51; xcText: "BUILD"; onCenter: false; xcFontSize: 28; textColor: Colors.border }
            XCText { x: 18; y: 94; width: parent.width - 36; xcText: "配置代价与文本展示，完善商店输出。"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned; xcWrapMode: true }
        }
    }
}
