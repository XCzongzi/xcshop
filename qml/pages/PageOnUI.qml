import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    workspace: true

    ContentBar {
        x: 20
        y: 16
        width: parent.width - 40
        height: Math.max(210, parent.height - y - 20)

        Rectangle {
            anchors.centerIn: parent
            width: 58
            height: 58
            radius: 18
            color: Colors.changeA(Colors.border, 0.18)
            XCText { anchors.centerIn: parent; xcText: "UI"; xcFontSize: 18; textColor: Colors.border }
        }
        XCText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + 46
            xcText: "选择一个界面文件"
            xcFontSize: 18
        }
        XCText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + 76
            xcText: "文件选中后，相关编辑控件会显示在这里。"
            xcFontSize: 13
            boldFont: false
            textColor: Colors.banned
        }
    }
}
