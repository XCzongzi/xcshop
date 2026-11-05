pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import xcshop

Controls.ToolTip {
    id: root

    // Bind active to the owner's hover or validation state.
    property bool active: false
    property bool beside: false
    property real maximumWidth: 480

    visible: active && text.length > 0 && parent !== null && parent.visible && parent.enabled
    delay: 500
    timeout: -1
    modal: false
    focus: false
    margins: 4
    horizontalPadding: 8
    verticalPadding: 2
    leftInset: 0
    rightInset: 0
    topInset: 0
    bottomInset: 0
    enter: null
    exit: null

    x: parent ? (beside ? parent.width + 4 : (parent.width - width) / 2) : 0
    y: parent && beside ? (parent.height - height) / 2 : -height - 4
    width: Math.min(implicitWidth, maximumWidth,
                    parent && parent.Window.window ? Math.max(1, parent.Window.window.width - margins * 2) : maximumWidth)
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: Math.max(20, contentItem.implicitHeight + topPadding + bottomPadding)

    contentItem: XCText {
        onCenter: false
        text: root.text
        xcFontSize: 12
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    background: Rectangle {
        radius: 4
        color: Colors.background_n
        border.width: 1
        border.color: Colors.border
    }
}
