import QtQuick
import xcshop

Item {
    id: root
    property var templates: []
    XCFile { id: xcFile }
    function loadTemplates() {
        var text = xcFile.read("templates.json")
        if (!text.length) { templates = []; return }
        try { templates = JSON.parse(text).Intros || [] }
        catch (error) { templates = [] }
    }
    Component.onCompleted: loadTemplates()

    Column {
        anchors.fill: parent
        spacing: 12
        SettingsPageHeader { title: "商店模板"; width: parent.width }
        ContentBar {
            id: templatesBar
            width: parent.width
            expanded: true
            color: Colors.changeA(Colors.foreground,
                                  Global.backgroundMode === "color" ? 0.34 : 0.48)
            title: "本地模板缓存"
            contentHeight: templateList.y + templateList.height + 16
            TextButton { x: 16; y: 48; text: "重新读取本地缓存"; height: 30; radius: 7; textSize: 12; widthBorderSize: 9; buttonColor: Colors.pressed; onClicked: root.loadTemplates() }
            XCText { x: 16; y: 90; visible: !root.templates.length; width: parent.width - 32; xcText: "尚未找到模板缓存。请在“创建项目”页面点击“获取”同步模板。"; onCenter: false; xcWrapMode: true; xcFontSize: 13; boldFont: false; textColor: Colors.banned }
            ListView {
                id: templateList
                x: 16; y: 90
                width: parent.width - 32; height: root.templates.length ? Math.min(contentHeight, root.templates.length * 78 + Math.max(0, root.templates.length - 1) * 8) : 0
                clip: true; model: root.templates; spacing: 8
                delegate: Rectangle {
                    id: templateDelegate
                    required property var modelData
                    width: ListView.view.width
                    height: versions.y + versions.height + 12
                    radius: 6
                    color: Colors.changeA(Colors.background, 0.18)
                    border.width: 1
                    border.color: Colors.changeA(Colors.text, 0.07)

                    XCText {
                        x: 16
                        y: 12
                        xcText: templateDelegate.modelData.id
                        onCenter: false
                        xcFontSize: 14
                    }
                    Flow {
                        id: versions
                        x: 16; y: 42; width: parent.width - 32; spacing: 6
                        Repeater {
                            model: templateDelegate.modelData.versions
                            delegate: TextButton { required property string modelData; text: modelData; height: 24; radius: 6; textSize: 11; widthBorderSize: 8; buttonColor: Colors.changeA(Colors.border, 0.25); firedColor: buttonColor; pressedColor: buttonColor }
                        }
                    }
                }
            }
        }
    }
}
