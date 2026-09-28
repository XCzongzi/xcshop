pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

Item {
    id: root

    property var options: []
    property string currentValue: ""
    property string placeholderText: "请选择"
    property bool compact: false

    signal valueActivated(string value)

    width: 220
    height: 34

    function indexForValue(value) {
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === String(value))
                return i
        }
        return -1
    }

    function syncCurrentIndex() {
        choice.currentIndex = indexForValue(currentValue)
    }

    onCurrentValueChanged: syncCurrentIndex()
    onOptionsChanged: syncCurrentIndex()
    Component.onCompleted: syncCurrentIndex()

    Controls.ComboBox {
        id: choice
        anchors.fill: parent
        model: root.options
        textRole: "label"
        valueRole: "value"
        leftPadding: 10
        rightPadding: 30

        contentItem: XCText {
            width: choice.availableWidth
            xcText: choice.currentIndex >= 0 && choice.currentIndex < root.options.length
                    ? root.options[choice.currentIndex].label : root.placeholderText
            onCenter: false
            onVCenter: true
            xcFontSize: root.compact ? 11 : 13
            boldFont: false
            textColor: choice.enabled ? Colors.text : Colors.banned
            elide: Text.ElideRight
        }

        indicator: XCText {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            xcText: choice.popup.visible ? "⌃" : "⌄"
            xcFontSize: 13
            boldFont: false
            textColor: Colors.banned
        }

        background: Rectangle {
            radius: 7
            color: choice.down || choice.popup.visible
                   ? Colors.changeA(Colors.background, 0.76)
                   : Colors.changeA(Colors.background, 0.38)
            border.width: 1
            border.color: choice.popup.visible || choice.hovered
                          ? Colors.changeA(Colors.border, 0.66)
                          : Colors.changeA(Colors.text, 0.10)

            Behavior on color { ColorAnimation { duration: 130 / Global.animationSpeed } }
            Behavior on border.color { ColorAnimation { duration: 130 / Global.animationSpeed } }
        }

        delegate: Controls.ItemDelegate {
            id: optionDelegate
            required property int index
            required property var model
            width: choice.popup.width - 8
            height: 32
            padding: 0
            highlighted: choice.highlightedIndex === index

            contentItem: XCText {
                x: 8
                width: parent.width - 16
                xcText: optionDelegate.model.label
                onCenter: false
                onVCenter: true
                xcFontSize: 12
                boldFont: false
                textColor: choice.currentIndex === optionDelegate.index ? Colors.border : Colors.text
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: 5
                color: optionDelegate.highlighted
                       ? Colors.changeA(Colors.fired, 0.42)
                       : Colors.transparent
            }
        }

        popup: Controls.Popup {
            y: choice.height + 5
            width: choice.width
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
            padding: 4

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: choice.popup.visible ? choice.delegateModel : null
                currentIndex: choice.highlightedIndex
                Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
            }

            background: Rectangle {
                radius: 9
                color: Qt.rgba(Colors.background_n.r, Colors.background_n.g,
                               Colors.background_n.b, 0.98)
                border.width: 1
                border.color: Colors.changeA(Colors.text, 0.13)
            }
        }

        onActivated: function(index) {
            if (index < 0 || index >= root.options.length)
                return
            root.currentValue = String(root.options[index].value)
            root.valueActivated(root.currentValue)
        }
    }
}
