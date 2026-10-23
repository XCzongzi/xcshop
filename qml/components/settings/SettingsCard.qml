import QtQuick
import xcshop

ContentSurface {
    id: root
    hoverEffectsEnabled: true
    property string title: ""
    property string description: ""
    property int contentHeight: 32
    property int padding: 16
    default property alias content: contentArea.data
    property alias headerActions: headerActionRow.data
    readonly property real headerHeight: Math.max(titleText.height, headerActionRow.height)

    width: parent ? parent.width : implicitWidth
    height: padding + headerHeight + (description.length ? descriptionText.height + 6 : 0) + 10 + contentHeight + padding
    radius: 10

    XCText {
        id: titleText
        xcText: root.title
        onCenter: false
        x: root.padding
        y: root.padding + (root.headerHeight - height) / 2
        width: Math.max(0, root.width - root.padding * 2 - (headerActionRow.width ? headerActionRow.width + 12 : 0))
        elide: Text.ElideRight
        xcFontSize: 16
    }
    Row {
        id: headerActionRow
        spacing: 8
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        y: root.padding + (root.headerHeight - height) / 2
    }
    XCText {
        id: descriptionText
        visible: root.description.length > 0
        xcText: root.description
        onCenter: false
        x: root.padding
        y: root.padding + root.headerHeight + 6
        width: parent.width - 2 * root.padding
        xcWrapMode: true
        xcFontSize: 12
        boldFont: false
        textColor: Colors.banned
    }
    Item {
        id: contentArea
        x: root.padding
        y: descriptionText.visible ? descriptionText.y + descriptionText.height + 10 : root.padding + root.headerHeight + 10
        width: parent.width - 2 * root.padding
        height: root.contentHeight
    }
}
