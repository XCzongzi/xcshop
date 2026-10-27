pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    anchors.fill: parent

    property var containerTypeOptions: []
    property bool showCancelButton: false
    property string selectedContainerType: ""

    signal confirmed(string containerTypeName)
    signal canceled

    ContentSurface {
        anchors.fill: parent
    }

    Item {
        id: selectionPanel
        anchors.centerIn: parent
        width: Math.min(720, parent.width - 48)
        height: Math.min(420, parent.height - 48)

        XCText {
            id: selectionTitle
            width: parent.width
            xcText: "选择容器界面类型"
            onCenter: false
            xcFontSize: 24
        }

        Row {
            id: actionRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 8

            TextButton {
                visible: root.showCancelButton
                height: 38
                radius: 8
                text: "取消"
                textSize: 14
                widthBorderSize: 16
                buttonColor: Colors.changeA(Colors.pressed, 0.82)
                onClicked: root.canceled()
            }

            ActionButton {
                id: confirmButton
                primary: true
                enabled: root.selectedContainerType.length > 0
                height: 38
                radius: 8
                text: "选择该界面"
                textSize: 14
                widthBorderSize: 16

                onClicked: root.confirmed(root.selectedContainerType)
            }
        }

        Flickable {
            id: optionsFlickable
            x: 0
            y: selectionTitle.height + 16
            width: parent.width - (selectionScrollBar.visible
                                   ? selectionScrollBar.width + 8 : 0)
            height: Math.max(0, actionRow.y - y - 16)
            contentWidth: width
            // Keep the content height valid during component construction.
            // A zero height makes the shared ScrollBar calculate an invalid
            // handle size before the option delegates have been laid out.
            contentHeight: Math.max(height, optionsContent.height)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            function clampContentY() {
                contentY = Math.max(0, Math.min(contentHeight - height, contentY))
            }

            onHeightChanged: clampContentY()
            onContentHeightChanged: clampContentY()

            Column {
                id: optionsContent
                width: optionsFlickable.width
                height: implicitHeight
                spacing: 12

                Grid {
                    id: containerTypeOptionsGrid
                    width: parent.width
                    columns: root.width >= 760 ? 2 : 1
                    columnSpacing: 8
                    rowSpacing: 6
                    readonly property int rowCount: Math.ceil(root.containerTypeOptions.length / columns)
                    height: root.containerTypeOptions.length
                            ? rowCount * 34 + (rowCount - 1) * rowSpacing : 0

                    Repeater {
                        model: root.containerTypeOptions

                        delegate: TextButton {
                            required property var model
                            readonly property var option: model.modelData
                            width: (containerTypeOptionsGrid.width
                                    - containerTypeOptionsGrid.columnSpacing
                                      * (containerTypeOptionsGrid.columns - 1))
                                   / containerTypeOptionsGrid.columns
                            height: 34
                            radius: 7
                            text: option.label
                            textSize: 13
                            boldFont: false
                            widthBorderSize: 8
                            btnSelected: root.selectedContainerType === option.type
                            buttonColor: Colors.changeA(Colors.foreground, 0.44)
                            firedColor: Colors.changeA(Colors.fired, 0.58)
                            pressedColor: Colors.changeA(Colors.border, 0.68)
                            onClicked: root.selectedContainerType = option.type
                        }
                    }
                }
            }

            // This handler intentionally belongs to the Flickable, so wheels
            // over the page title and confirm button do not move the list.
            WheelHandler {
                target: optionsFlickable
                onWheel: function(event) {
                    var delta = event.angleDelta.y
                    if (delta === 0)
                        delta = event.pixelDelta.y
                    if (delta === 0)
                        return

                    optionsFlickable.contentY = Math.max(
                                0, Math.min(optionsFlickable.contentHeight - optionsFlickable.height,
                                            optionsFlickable.contentY - delta))
                    event.accepted = true
                }
            }
        }

        ScrollBar {
            id: selectionScrollBar
            x: optionsFlickable.x + optionsFlickable.width + 8
            y: optionsFlickable.y
            height: optionsFlickable.height
            content_height: Math.max(optionsFlickable.height, optionsFlickable.contentHeight)
            animatePosition: false
            onHeight_outputChanged: {
                if (Math.abs(optionsFlickable.contentY - height_output) > 0.5)
                    optionsFlickable.contentY = height_output
            }
        }

        Connections {
            target: optionsFlickable
            function onContentYChanged() {
                if (selectionScrollBar.visible)
                    selectionScrollBar.setContentOffset(optionsFlickable.contentY)
            }
        }

    }
}
