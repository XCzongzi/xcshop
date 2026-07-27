import QtQuick
import xcshop

Item {
    id: root
    property string title: ""
    property string subtitle: ""
    implicitHeight: subtitle.length ? 58 : 34

    XCText {
        xcText: root.title
        onCenter: false
        xcFontSize: 25
    }
    XCText {
        visible: root.subtitle.length > 0
        y: 38
        width: parent.width
        xcText: root.subtitle
        onCenter: false
        xcFontSize: 13
        boldFont: false
        textColor: Colors.banned
    }
}
