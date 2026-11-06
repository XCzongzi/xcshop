pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BasePage {
    id: root
    color: Colors.transparent
    fullScreen: true

    property int currentSection: 0
    property int displayedSection: 0
    onCurrentSectionChanged: {
        for (var i = 0; i < sectionButtons.count; ++i) {
            var button = sectionButtons.itemAt(i)
            if (button)
                button.setSelected(i === currentSection, false)
        }
        if (sectionMotion) sectionMotion.changeTo(currentSection)
    }
    Component.onCompleted: {
        displayedSection = currentSection
        sectionMotion.reset(currentSection)
    }
    readonly property var sections: [
        { title: "界面", page: interfacePage },
        { title: "构建套件", page: kitsPage },
        { title: "构建器", page: builderPage },
        { title: "物品信息", page: itemsPage }
    ]

    Component { id: interfacePage; SettingsInterface {} }
    Component { id: kitsPage; SettingsBuildKits {} }
    Component { id: builderPage; SettingsBuilder {} }
    Component { id: itemsPage; SettingsItems {} }

    Item {
        anchors.fill: parent

        Rectangle {
            id: sidebar
            width: 224
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Colors.transparent
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Colors.changeA(
                               Qt.tint(Colors.panel,
                                       Colors.changeA(Colors.border, 0.18)),
                               Global.backgroundMode === "color" ? 0.48 : 0.62)
                }
                GradientStop {
                    position: 0.46
                    color: Colors.changeA(Colors.panel,
                                          Global.backgroundMode === "color" ? 0.34 : 0.48)
                }
                GradientStop {
                    position: 1.0
                    color: Colors.changeA(
                               Qt.tint(Colors.background_n,
                                       Colors.changeA(Colors.border, 0.10)),
                               Global.backgroundMode === "color" ? 0.22 : 0.34)
                }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.leftMargin: 20
                anchors.rightMargin: 24
                spacing: 8
                TextButton {
                    width: parent.width; height: 34; radius: 7
                    text: "← 返回"; textSize: 13; widthBorderSize: 10
                    buttonColor: Colors.transparent
                    firedColor: Colors.changeA(Colors.background_n, 0.24)
                    pressedColor: Colors.changeA(Colors.pressed, 0.54)
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

            Rectangle {
                x: 0
                y: 86
                width: 3
                height: 23
                radius: 2
                color: Colors.border
            }
        }

        Rectangle {
            anchors.left: sidebar.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Colors.changeA(Colors.border, 0.18)
        }
        Item {
            id: contentArea
            anchors.left: sidebar.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            clip: true
            Loader {
                id: sectionLoader
                objectName: "settingsSectionLoader"
                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 32
                anchors.topMargin: 24
                anchors.bottomMargin: 24
                opacity: sectionMotion.contentOpacity
                transform: Translate { y: sectionMotion.contentOffset }
                sourceComponent: root.sections[root.displayedSection].page
            }
            PageTransition {
                id: sectionMotion
                objectName: "settingsSectionTransition"
                onCommit: function(value) { root.displayedSection = value }
                onFinished: { if (sectionLoader.item) sectionLoader.item.forceActiveFocus() }
            }
        }
    }
}
