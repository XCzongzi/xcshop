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

    property bool connectionDeleting: false
    property string removalGroupId: ""
    ListModel { id: connectionModel }
    AnimatedListRemoval {
        id: connectionRemoval
        onFinished: function (row) {
            if (root.uiPage && root.groupId === root.removalGroupId)
                root.uiPage.removeNestedGroupLayoutInputConnection(root.removalGroupId, row)
            root.connectionDeleting = false
        }
    }

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
        layoutInputId.text = input.id || ""
        resultScoreboard.text = input.result.scoreboard || ""
        resultTarget.text = input.result.target || ""
        defaultValueInput.text = input.defaultValue === undefined ? "" : String(input.defaultValue)
    }

    function refresh() {
        // Refresh can destroy the sliding row before it emits deleteClicked.
        connectionRemoval.cancel()
        connectionDeleting = false
        root.rebuildModel()
        Qt.callLater(root.syncEditors)
    }

    function commitResult() {
        if (!root.uiPage || !root.groupId.length)
            return
        root.uiPage.setNestedGroupLayoutInputResult(
                    root.groupId, resultScoreboard.text.trim(), resultTarget.text.trim())
    }

    function commitId() {
        if (!root.uiPage || !root.groupId.length)
            return
        var normalizedId = layoutInputId.text.trim()
        layoutInputId.text = normalizedId
        root.uiPage.setNestedGroupLayoutInputId(root.groupId, normalizedId)
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
            enabled: !root.connectionDeleting
            height: implicitHeight - connectionRemoval.offset
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

            XCText {
                visible: root.inputEnabled
                width: parent.width
                xcText: "布局输入器 ID"
                xcFontSize: 13
                boldFont: false
                onCenter: false
                textColor: Colors.changeA(Colors.text, 0.82)
            }

            XCTextField {
                id: layoutInputId
                visible: root.inputEnabled
                width: parent.width
                height: 34
                placeholderText: "可在游戏中以此id调用该输入器"
                onEditingFinished: root.commitId()
            }

            Rectangle {
                width: parent.width
                implicitHeight: resultContent.height + 20
                visible: root.inputEnabled
                radius: 8
                color: Colors.changeA(Colors.background, 0.28)
                border.width: 1
                border.color: Colors.changeA(Colors.outline, 0.10)

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

            Row {
                visible: root.inputEnabled
                width: parent.width
                spacing: 8

                XCText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - defaultValueLabel.width
                                    - defaultValueInput.width - parent.spacing * 2)
                    xcText: "输入界面"
                    xcFontSize: 13
                    onCenter: false
                }

                XCText {
                    id: defaultValueLabel
                    anchors.verticalCenter: parent.verticalCenter
                    xcText: "默认值"
                    xcFontSize: 11
                    boldFont: false
                    onCenter: false
                    textColor: Colors.changeA(Colors.text, 0.78)
                }

                XCTextField {
                    id: defaultValueInput
                    width: 100
                    height: 30
                    placeholderText: "必填整数"
                    validator: RegularExpressionValidator { regularExpression: /-?[0-9]+/ }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    onActiveFocusChanged: {
                        if (!activeFocus && !acceptableInput) {
                            var input = root.inputData()
                            text = input && input.defaultValue !== undefined
                                    ? String(input.defaultValue) : ""
                        }
                    }
                    onEditingFinished: {
                        if (root.uiPage && root.groupId.length)
                            root.uiPage.setNestedGroupLayoutInputDefaultValue(root.groupId, text)
                    }
                }
            }

            XCText {
                visible: root.inputEnabled && !defaultValueInput.acceptableInput
                width: parent.width
                xcText: "默认值不能为空，且必须为整数"
                xcFontSize: 11
                boldFont: false
                onCenter: false
                textColor: Colors.error
            }

            Repeater {
                id: connectionRepeater
                model: root.inputEnabled ? connectionModel : null

                delegate: LayoutInputConnection {
                    required property var model
                    objectName: "layoutConnectionRow" + index

                    width: inputColumn.width
                    index: model.index
                    z: -model.index
                    modelData: {
                        var input = root.inputData()
                        return input && Array.isArray(input.connections)
                                && model.index >= 0 && model.index < input.connections.length
                                ? input.connections[model.index] : ({})
                    }
                    listShift: connectionRemoval.shiftFor(index)
                    onDeletionStarted: {
                        root.removalGroupId = root.groupId
                        root.connectionDeleting = true
                    }
                    onDeleteClicked: connectionRemoval.begin(index, height + inputColumn.spacing)
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
                transform: Translate {
                    y: -connectionRemoval.offset
                }
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
