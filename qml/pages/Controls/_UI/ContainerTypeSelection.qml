pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    anchors.fill: parent

    property var blockContainerOptions: []
    property var entityContainerOptions: []
    property bool showEntityContainers: true
    property bool showCancelButton: false
    property string selectedContainerId: ""

    signal confirmed(string containerId)
    signal canceled()

    Rectangle {
        anchors.fill: parent
        color: Colors.changeA(Colors.foreground, 0.18)
        radius: 10
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.07)
    }

    Item {
        id: selectionPanel
        anchors.centerIn: parent
        width: Math.min(720, parent.width - 48)
        height: Math.min(620, parent.height - 48)

        XCText {
            id: selectionTitle
            width: parent.width
            xcText: "选择容器类型"
            onCenter: false
            xcFontSize: 24
        }

        XCText {
            id: selectionDescription
            y: selectionTitle.height + 6
            width: parent.width
            xcText: "请选择该 UI 对应的 Minecraft 存储容器。确认后将保存容器界面编号并进入编辑工作区。"
            onCenter: false
            xcWrapMode: true
            xcFontSize: 14
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.78)
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

            TextButton {
                id: confirmButton
                enabled: root.selectedContainerId.length > 0
                height: 38
                radius: 8
                text: "选择该容器"
                textSize: 14
                widthBorderSize: 16
                buttonColor: Colors.changeA(Colors.border, 0.72)
                firedColor: Colors.changeA(Colors.border, 0.88)
                pressedColor: Colors.border
                textColor: "#1b1b1b"
                onClicked: root.confirmed(root.selectedContainerId)
            }
        }

        Flickable {
            id: optionsFlickable
            x: 0
            y: selectionDescription.y + selectionDescription.height + 16
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

                XCText {
                    width: parent.width
                    xcText: "方块容器"
                    onCenter: false
                    xcFontSize: 16
                }

                Grid {
                    id: blockOptionsGrid
                    width: parent.width
                    columns: root.width >= 760 ? 2 : 1
                    columnSpacing: 8
                    rowSpacing: 6
                    readonly property int rowCount: Math.ceil(root.blockContainerOptions.length / columns)
                    height: root.blockContainerOptions.length
                            ? rowCount * 34 + (rowCount - 1) * rowSpacing : 0

                    Repeater {
                        model: root.blockContainerOptions

                        delegate: TextButton {
                            required property var model
                            readonly property var option: model.modelData
                            width: (blockOptionsGrid.width
                                    - blockOptionsGrid.columnSpacing * (blockOptionsGrid.columns - 1))
                                   / blockOptionsGrid.columns
                            height: 34
                            radius: 7
                            text: option.label
                            textSize: 13
                            boldFont: false
                            widthBorderSize: 8
                            btnSelected: root.selectedContainerId === option.id
                            buttonColor: Colors.changeA(Colors.foreground, 0.44)
                            firedColor: Colors.changeA(Colors.fired, 0.58)
                            pressedColor: Colors.changeA(Colors.border, 0.68)
                            onClicked: root.selectedContainerId = option.id
                        }
                    }
                }

                XCText {
                    visible: root.showEntityContainers && root.entityContainerOptions.length > 0
                    width: parent.width
                    xcText: "实体容器"
                    onCenter: false
                    xcFontSize: 16
                }

                Grid {
                    id: entityOptionsGrid
                    visible: root.showEntityContainers && root.entityContainerOptions.length > 0
                    width: parent.width
                    columns: root.width >= 760 ? 2 : 1
                    columnSpacing: 8
                    rowSpacing: 6
                    readonly property int rowCount: Math.ceil(root.entityContainerOptions.length / columns)
                    height: visible ? rowCount * 34 + (rowCount - 1) * rowSpacing : 0

                    Repeater {
                        model: root.entityContainerOptions

                        delegate: TextButton {
                            required property var model
                            readonly property var option: model.modelData
                            width: (entityOptionsGrid.width
                                    - entityOptionsGrid.columnSpacing * (entityOptionsGrid.columns - 1))
                                   / entityOptionsGrid.columns
                            height: 34
                            radius: 7
                            text: option.label
                            textSize: 13
                            boldFont: false
                            widthBorderSize: 8
                            btnSelected: root.selectedContainerId === option.id
                            buttonColor: Colors.changeA(Colors.foreground, 0.44)
                            firedColor: Colors.changeA(Colors.fired, 0.58)
                            pressedColor: Colors.changeA(Colors.border, 0.68)
                            onClicked: root.selectedContainerId = option.id
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
