pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true

    property int currentSection: 0
    onCurrentSectionChanged: {
        for (var i = 0; i < sectionButtons.count; ++i) {
            var button = sectionButtons.itemAt(i)
            if (button)
                button.setSelected(i === currentSection, false)
        }
    }
    readonly property var sections: [
        { title: "界面", page: interfacePage },
        { title: "商店模板", page: templatesPage },
        { title: "物品信息", page: itemsPage }
    ]

    Component { id: interfacePage; SettingsInterface {} }
    Component { id: templatesPage; SettingsTemplates {} }
    Component { id: itemsPage; SettingsItems {} }

    Rectangle {
        anchors.fill: parent
        color: Colors.transparent

        Rectangle {
            id: sidebar
            width: 216
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Colors.changeA(Colors.foreground, 0.54)

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                TextButton {
                    width: parent.width; height: 36; radius: 8
                    text: "← 返回"; textSize: 13; widthBorderSize: 10
                    buttonColor: Colors.changeA(Colors.pressed, 0.80)
                    firedColor: Colors.changeA(Colors.border, 0.22)
                    onClicked: root.pageEvent("Settings.back", {})
                }
                Item { width: 1; height: 12 }
                XCText { xcText: "设置"; onCenter: false; xcFontSize: 25 }
                Item { width: 1; height: 12 }
                Repeater {
                    id: sectionButtons
                    model: root.sections
                    delegate: SettingsNavButton {
                        required property int index
                        required property var modelData
                        text: modelData.title
                        Component.onCompleted: setSelected(root.currentSection === index, true)
                        onClicked: root.currentSection = index
                    }
                }
                Item { width: 1; height: Math.max(1, parent.height - y) }
            }
        }

        Rectangle { anchors.left: sidebar.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: Colors.changeA(Colors.text, 0.12) }
        Rectangle {
            anchors.left: sidebar.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 16; radius: 12; color: Colors.changeA(Colors.foreground, 0.30); clip: true
            Loader { anchors.fill: parent; anchors.margins: 20; sourceComponent: root.sections[root.currentSection].page }
        }
    }
}
