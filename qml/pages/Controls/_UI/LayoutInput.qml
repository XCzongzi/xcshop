pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root

    property var uiPage: null
    readonly property string groupId: uiPage ? uiPage.selectedNestedGroupId : ""
    readonly property int layoutRevision: uiPage ? uiPage.layoutRevision : 0
    readonly property var selectedGroup: {
        return root.layoutRevision >= 0 && groupId.length && uiPage
                ? uiPage.selectedNestedGroup() : null
    }
    readonly property bool hasSelectedGroup: selectedGroup !== null
    readonly property bool inputEnabled: root.layoutRevision >= 0
                                       && hasSelectedGroup
                                       && selectedGroup.layoutInput.enabled === true

    width: parent ? parent.width : 0
    height: parent ? parent.height - 16 : 0
    y: 16

    ListModel { id: connectionModel }

    function inputData() {
        return root.hasSelectedGroup ? root.selectedGroup.layoutInput : null
    }

    function rebuildModel() {
        connectionModel.clear()
        var input = root.inputData()
        if (!input || !Array.isArray(input.connections))
            return
        for (var index = 0; index < input.connections.length; ++index)
            connectionModel.append({ "serial": index })
    }

    function syncEditors() {
        var input = root.inputData()
        if (!input)
            return
        enableInput.checked = input.enabled === true
        resultScoreboard.text = input.result.scoreboard || ""
        resultTarget.text = input.result.target || ""
    }

    function refresh() {
        root.rebuildModel()
        Qt.callLater(root.syncEditors)
    }

    function commitResult() {
        if (!root.uiPage || !root.groupId.length)
            return
        root.uiPage.setNestedGroupLayoutInputResult(
                    root.groupId, resultScoreboard.text.trim(), resultTarget.text.trim())
    }

    Flickable {
        id: inputFlickable
        anchors.fill: parent
        visible: root.hasSelectedGroup
        clip: true
        contentWidth: width
        contentHeight: inputColumn.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: inputColumn
            width: inputFlickable.width
            spacing: 10

            XCCheckBox {
                id: enableInput
                width: parent.width
                text: "为此嵌套组启用输入器"
                onToggled: function(checked) {
                    if (root.uiPage && root.groupId.length)
                        root.uiPage.setNestedGroupLayoutInputEnabled(root.groupId, checked)
                }
            }

            Rectangle {
                width: parent.width
                implicitHeight: resultContent.height + 20
                visible: root.inputEnabled
                radius: 8
                color: Colors.changeA(Colors.background, 0.28)
                border.width: 1
                border.color: Colors.changeA(Colors.text, 0.10)

                Column {
                    id: resultContent
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 6

                    XCText {
                        width: parent.width
                        xcText: "用于接收结果的："
                        xcFontSize: 13
                        onCenter: false
                    }

                    XCText {
                        width: parent.width
                        xcText: "计分板名称"
                        xcFontSize: 11
                        boldFont: false
                        onCenter: false
                        textColor: Colors.changeA(Colors.text, 0.78)
                    }

                    XCTextField {
                        id: resultScoreboard
                        width: parent.width
                        height: 30
                        placeholderText: "objective"
                        onEditingFinished: root.commitResult()
                    }

                    XCText {
                        width: parent.width
                        xcText: "目标"
                        xcFontSize: 11
                        boldFont: false
                        onCenter: false
                        textColor: Colors.changeA(Colors.text, 0.78)
                    }

                    XCTextField {
                        id: resultTarget
                        width: parent.width
                        height: 30
                        placeholderText: "@s、@p 或玩家名"
                        onEditingFinished: root.commitResult()
                    }
                }
            }

            XCText {
                visible: root.inputEnabled
                width: parent.width
                xcText: "输入界面"
                xcFontSize: 13
                onCenter: false
            }

            Repeater {
                id: connectionRepeater
                model: root.inputEnabled ? connectionModel : null

                delegate: LayoutInputConnection {
                    required property var model

                    width: inputColumn.width
                    index: model.index
                    z: -model.index
                    modelData: {
                        var input = root.inputData()
                        return input && Array.isArray(input.connections)
                                && model.index < input.connections.length
                                ? input.connections[model.index] : ({})
                    }
                    onDeleteClicked: {
                        if (model.index < connectionModel.count - 1) {
                            connectionRepeater.itemAt(model.index + 1).nearest = true
                            for (var index = model.index + 1;
                                 index < connectionModel.count; ++index) {
                                connectionRepeater.itemAt(index).afterDeleting(height,
                                                                             model.index)
                            }
                        } else {
                            root.uiPage.removeNestedGroupLayoutInputConnection(
                                        root.groupId, model.index)
                        }
                    }
                    onDeleteAnimFinished: function(currentIndex) {
                        root.uiPage.removeNestedGroupLayoutInputConnection(
                                    root.groupId, currentIndex)
                    }
                    onUpdateData: {
                        root.uiPage.updateNestedGroupLayoutInputConnection(
                                    root.groupId, model.index, modelData.element,
                                    modelData.value)
                    }
                }
            }

            TextButton {
                visible: root.inputEnabled
                width: parent.width
                height: 40
                radius: 8
                text: "＋ 新增匹配"
                textSize: 13
                boldFont: false
                textColor: Colors.banned
                buttonColor: Colors.changeA(Colors.background, 0.38)
                firedColor: Colors.changeA(Colors.fired, 0.62)
                pressedColor: Colors.changeA(Colors.border, 0.55)
                onClicked: root.uiPage.addNestedGroupLayoutInputConnection(root.groupId)
            }
        }

        onContentYChanged: {
            if (!inputScrollBar.dragging)
                inputScrollBar.setContentOffset(contentY)
        }
        onMovementStarted: inputScrollBar.animatePosition = false
        onMovementEnded: inputScrollBar.animatePosition = true
    }

    XCText {
        visible: !root.hasSelectedGroup
        width: parent.width
        xcText: "请先在布局管理器中选择一个嵌套组"
        xcFontSize: 13
        boldFont: false
        onCenter: false
        textColor: Colors.banned
    }

    ScrollBar {
        id: inputScrollBar
        visible: root.hasSelectedGroup
        z: 1
        x: parent.width + 8
        height: parent.height
        content_height: inputFlickable.contentHeight
        layout_determines: root.uiPage ? root.uiPage.layoutRevision : 0
        onHeight_outputChanged: {
            if (!inputFlickable.moving)
                inputFlickable.contentY = height_output
        }
    }

    Connections {
        target: root.uiPage

        function onLayoutDataChanged() { root.refresh() }
        function onSelectedNestedGroupIdChanged() {
            inputFlickable.contentY = 0
            root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
