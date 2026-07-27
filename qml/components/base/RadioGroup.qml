pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Rectangle {
    id: root
    property string text: ""
    property var options: []
    property int selected: -1
    property int initialOption: 0
    readonly property bool hasLabel: text.length > 0

    signal clicked()

    height: 44
    width: optionSurface.x + optionSurface.width + 4
    radius: 10
    color: Colors.changeA(Colors.background, 0.48)
    border.width: 1
    border.color: Colors.changeA(Colors.text, 0.10)

    XCText {
        id: labelText
        visible: root.hasLabel
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        xcText: root.text
        onCenter: false
        xcFontSize: 14
    }

    Rectangle {
        id: optionSurface
        x: root.hasLabel ? labelText.x + labelText.width + 12 : 4
        anchors.verticalCenter: parent.verticalCenter
        width: optionRow.width + 8
        height: 34
        radius: 8
        color: Colors.changeA(Colors.foreground, 0.58)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.07)

        Rectangle {
            id: selectedHighlight
            visible: root.selected >= 0 && root.selected < optionRepeater.count
            x: root.selected >= 0 && root.selected < optionRepeater.count ? optionRepeater.itemAt(root.selected).x + 2 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: root.selected >= 0 && root.selected < optionRepeater.count ? optionRepeater.itemAt(root.selected).width : 0
            height: parent.height - 4
            radius: 6
            color: Colors.changeA(Colors.border, 0.72)

            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        Row {
            id: optionRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                id: optionRepeater
                model: root.options
                delegate: TextButton {
                    required property int index
                    required property var model
                    text: model.modelData
                    textSize: 13
                    height: 30
                    radius: 6
                    widthBorderSize: 9
                    buttonColor: Colors.transparent
                    firedColor: Colors.changeA(Colors.fired, 0.26)
                    pressedColor: Colors.transparent
                    btnSelected: root.selected === index
                    onClicked: {
                        root.selected = index
                        root.clicked()
                    }
                }
            }
        }
    }

    Component.onCompleted: root.selected = root.initialOption
}
