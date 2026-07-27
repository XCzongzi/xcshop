import QtQuick
import xcshop

Rectangle {
    id: root
    property string title: ""
    property string description: ""
    property int contentHeight: 32
    property int padding: 16
    default property alias content: contentArea.data

    width: parent ? parent.width : implicitWidth
    height: padding + titleText.height + (description.length ? descriptionText.height + 6 : 0) + 10 + contentHeight + padding
    radius: 10
    color: Colors.changeA(Colors.foreground, 0.65)

    XCText {
        id: titleText
        xcText: root.title
        onCenter: false
        x: root.padding
        y: root.padding
        xcFontSize: 16
    }
    XCText {
        id: descriptionText
        visible: root.description.length > 0
        xcText: root.description
        onCenter: false
        x: root.padding
        y: titleText.y + titleText.height + 6
        width: parent.width - 2 * root.padding
        xcFontSize: 12
        boldFont: false
        textColor: Colors.banned
    }
    Item {
        id: contentArea
        x: root.padding
        y: descriptionText.visible ? descriptionText.y + descriptionText.height + 10 : titleText.y + titleText.height + 10
        width: parent.width - 2 * root.padding
        height: root.contentHeight
    }
}
