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
        contentHeight: 78
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
    }

    
}
