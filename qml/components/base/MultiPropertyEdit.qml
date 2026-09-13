pragma ComponentBehavior: Bound
import QtQuick
import xcshop

// A compact property editor with a selector in its header and one custom
// editor surface below it. Add editor items directly; the visible one is
// measured automatically.
Item {
    id: root

    property string text: ""
    property var options: []
    property int selected: -1
    property int initialOption: 0
    property int headerHeight: 38
    property int contentPadding: 10
    property int minimumEditorHeight: 32
    property string emptyText: "请选择需要编辑的属性"

    readonly property bool hasLabel: text.length > 0
    readonly property Item currentEditor: {
        for (var index = 0; index < editorContent.children.length; ++index) {
            var item = editorContent.children[index]
            if (item.visible)
                return item
        }
        return null
    }
    readonly property real contentHeight: currentEditor
                                        ? currentEditor.y
                                          + Math.max(currentEditor.implicitHeight,
                                                     currentEditor.height)
                                        : 0

    default property alias content: editorContent.data

    signal clicked()

    implicitWidth: 280
    implicitHeight: headerHeight + contentPadding
                    + Math.max(contentHeight, minimumEditorHeight)
    height: implicitHeight

    function selectOption(index) {
        if (index < 0 || index >= options.length)
            return

        selected = index
        clicked()
    }

    function ensureSelection() {
        if (!options.length) {
            selected = -1
            return
        }

        if (selected < 0 || selected >= options.length)
            selected = Math.min(Math.max(initialOption, 0), options.length - 1)
    }

    onOptionsChanged: ensureSelection()
    Component.onCompleted: ensureSelection()

    Item {
        id: header
        width: parent.width
        height: root.headerHeight
        clip: true

        XCText {
            id: labelText
            visible: root.hasLabel
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.text
            onCenter: false
            xcFontSize: 14
        }

        Flickable {
            id: optionFlickable
            x: root.hasLabel ? labelText.x + labelText.width + 12 : 0
            width: parent.width - x
            height: 32
            anchors.bottom: parent.bottom
            contentWidth: optionContent.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            interactive: contentWidth > width

            Item {
                id: optionContent
                width: optionRow.width
                height: parent.height

                Rectangle {
                    id: activePropertyMarker
                    visible: root.selected >= 0 && root.selected < optionRepeater.count
                    x: root.selected >= 0 && root.selected < optionRepeater.count
                       ? optionRepeater.itemAt(root.selected).x : 0
                    y: parent.height - height - 3
                    width: root.selected >= 0 && root.selected < optionRepeater.count
                           ? optionRepeater.itemAt(root.selected).width : 0
                    height: 3
                    radius: height / 2
                    color: Colors.border

                    Behavior on x { NumberAnimation { duration: 150 / Global.animationSpeed; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 150 / Global.animationSpeed; easing.type: Easing.OutCubic } }
                }

                Row {
                    id: optionRow
                    height: parent.height
                    spacing: 3

                    Repeater {
                        id: optionRepeater
                        model: root.options

                        delegate: TextButton {
                            required property int index
                            required property var model

                            anchors.verticalCenter: parent.verticalCenter
                            text: model.modelData
                            textSize: 13
                            height: 32
                            radius: 5
                            widthBorderSize: 8
                            boldFont: root.selected === index
                            btnSelected: false
                            textColor: root.selected === index ? Colors.text : Colors.changeA(Colors.text, 0.70)
                            firedColor: Colors.changeA(Colors.fired, 0.45)
                            pressedColor: Colors.changeA(Colors.border, 0.72)
                            onClicked: root.selectOption(index)
                        }
                    }
                }
            }
        }

    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.headerHeight - 1
        height: 1
        color: Colors.changeA(Colors.text, 0.13)
    }

    Item {
        id: contentArea
        x: root.contentPadding
        y: root.headerHeight + root.contentPadding
        width: parent.width - root.contentPadding * 2
        height: Math.max(0, root.height - y)

        Item {
            id: editorContent
            anchors.fill: parent
        }

        XCText {
            visible: !root.currentEditor
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.emptyText
            xcFontSize: 13
            boldFont: false
            onCenter: false
            textColor: Colors.banned
        }
    }
}
