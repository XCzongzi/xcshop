import QtQuick
import QtQuick.Controls as Controls
import xcshop

XCScrollView {
    id: root
    property string title: ""
    default property alias sections: sectionsColumn.data
    contentHeight: sectionsColumn.implicitHeight
    rightPadding: settingsScrollBar.visible ? settingsScrollBar.width + 12 : 0
    Controls.ScrollBar.vertical: XCScrollBar {
        id: settingsScrollBar
        parent: root
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
    Column {
        id: sectionsColumn
        width: root.availableWidth
        spacing: 16
        SettingsPageHeader {
            title: root.title
            width: parent.width
        }
    }
}
