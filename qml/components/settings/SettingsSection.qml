import QtQuick
import xcshop

XCScrollView {
    id: root
    property string title: ""
    default property alias sections: sectionsColumn.data
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
