import QtQuick
import xcshop

Item {
    id: root
    required property var operation
    required property int index
    property real listShift: 0
    property bool animateInsertion: false
    property real insertionProgress: animateInsertion ? 0 : 1
    readonly property bool appearing: insertionAnimation.running
    readonly property real contentHeight: body.y + body.height + 20
    property bool deleting: false
    property bool costDeleting: false
    signal edited
    signal removalStarted
    signal removeRequested
    signal moveUpRequested
    signal insertionFinished
    height: contentHeight * insertionProgress
    clip: insertionProgress < 1
    function requestRemove() {
        if (deleting || costDeleting || appearing)
            return;
        deleting = true;
        removalStarted();
        deleteAnimation.start();
    }
    function addCost() {
        operation.cost.push({
            element: "",
            amount: "1"
        });
        costRows.add(operation.cost[operation.cost.length - 1]);
        edited();
    }
    function removeCost(row) {
        operation.cost.splice(row, 1);
        costRows.removeAt(row);
        edited();
    }
    Component.onCompleted: {
        for (var i = 0; i < operation.cost.length; ++i)
            costRows.add(operation.cost[i]);
        if (animateInsertion)
            insertionAnimation.start();
    }
    NumberAnimation {
        id: insertionAnimation
        target: root
        property: "insertionProgress"
        from: 0
        to: 1
        duration: 220 / Global.animationSpeed
        easing.type: Easing.OutCubic
        onFinished: root.insertionFinished()
    }
    AnimatedListRemoval {
        id: costRemoval
        onFinished: function (row) {
            root.removeCost(row);
            root.costDeleting = false;
        }
    }
    ContentSurface {
        id: frame
        objectName: "operationCardFrame"
        width: root.width
        height: root.height
        opacity: root.insertionProgress
        clip: true
        transform: Translate {
            y: root.listShift
        }
        Rectangle {
            id: cardHeader
            objectName: "operationCardHeader"
            width: parent.width
            height: 32
            radius: 9
            color: Colors.changeA(Colors.background, 0.38)
            border.width: 1
            border.color: Colors.changeA(Colors.outline, 0.07)
            Rectangle {
                x: 1
                y: 4
                width: 4
                height: 24
                radius: 2
                color: Colors.border
            }
            XCTextField {
                id: titleInput
                objectName: "operationTitle"
                x: 14
                y: 4
                height: 24
                width: moveUpButton.x - x - 10
                font.pixelSize: 13
                text: root.operation.title
                placeholderText: "名称"
                highlightMacros: true
                background: Rectangle {
                    radius: 4
                    color: titleInput.activeFocus ? Colors.changeA(Colors.background, 0.4) : Colors.transparent
                }
                onEditingFinished: {
                    root.operation.title = text;
                    root.edited();
                }
            }
        }
        ImageButton {
            id: moveUpButton
            objectName: "moveOperationUpButton"
            x: ctrlBar.x - width
            btnSize: ctrlBar.height
            imgSize: 16
            imageSource: "qrc:/assets/gui/controls/expand_up.png"
            btnbackground: Colors.transparent
            radius: 0
            enabled: root.index > 0
            opacity: enabled ? 1 : 0.35
            onClicked: root.moveUpRequested()
        }
        Rectangle {
            id: ctrlBar
            z: 3
            color: Colors.changeA(Colors.card, 0.94)
            width: 32 + 16 + ctrlBarText.width
            height: 32
            x: parent.width - width
            radius: frame.radius
            topLeftRadius: 0
            topRightRadius: radius
            bottomLeftRadius: radius
            bottomRightRadius: 0
            border.width: 1
            border.color: Colors.changeA(Colors.outline, 0.10)
            ImageButton {
                objectName: "removeOperationButton"
                btnSize: 32
                imgSize: 16
                imageSource: "qrc:/assets/gui/titleBar/close.png"
                radius: frame.radius
                topLeftRadius: 0
                topRightRadius: radius
                bottomLeftRadius: radius
                bottomRightRadius: 0
                btnbackground: Colors.changeA(Colors.error, 0.72)
                btnfired: Colors.changeA(Colors.error, 0.90)
                btnpressed: Colors.error
                onClicked: root.requestRemove()
            }
            XCText {
                id: ctrlBarText
                objectName: "operationNumber"
                x: parent.width - width - 8
                xcText: "操作" + (root.index + 1)
                onCenter: false
                onVCenter: true
                xcFontSize: 16
                boldFont: false
                textColor: Colors.banned
            }
        }
        NumberAnimation {
            id: deleteAnimation
            target: frame
            property: "x"
            to: root.width
            duration: 200 / Global.animationSpeed
            easing.type: Easing.InCubic
            onFinished: {
                frame.opacity = 0;
                root.removeRequested();
            }
        }
        Column {
            id: body
            x: 16
            y: 48
            width: parent.width - 32
            spacing: 14
            Flow {
                objectName: "operationOptions"
                width: parent.width
                spacing: 16
                XCCheckBox {
                    objectName: "operationShowInDisplay"
                    text: "在展示文本中显示"
                    checked: root.operation.showInDisplay
                    onToggled: function (value) {
                        root.operation.showInDisplay = value;
                        root.edited();
                    }
                }
                XCCheckBox {
                    objectName: "operationSuccessHint"
                    text: "成功提示"
                    checked: root.operation.successHint !== false
                    onToggled: function (value) {
                        root.operation.successHint = value;
                        root.edited();
                    }
                }
                XCCheckBox {
                    objectName: "operationFailHint"
                    text: "失败提示"
                    checked: root.operation.failHint !== false
                    onToggled: function (value) {
                        root.operation.failHint = value;
                        root.edited();
                    }
                }
                XCCheckBox {
                    objectName: "operationReturnOnSuccess"
                    text: "成功后返回"
                    checked: root.operation.returnOnSuccess === true
                    onToggled: function (value) {
                        root.operation.returnOnSuccess = value;
                        root.edited();
                    }
                }
            }
            Grid {
                id: operationFields
                width: parent.width
                columns: width >= 840 ? 2 : 1
                columnSpacing: 24
                rowSpacing: 16
                Item_triggerBar {
                    objectName: "operationTrigger"
                    width: (operationFields.width - operationFields.columnSpacing * (operationFields.columns - 1)) / operationFields.columns
                    modelData: root.operation.trigger
                    onUpdateData: root.edited()
                }
                Column {
                    id: costColumn
                    width: (operationFields.width - operationFields.columnSpacing * (operationFields.columns - 1)) / operationFields.columns
                    height: implicitHeight - costRemoval.offset
                    spacing: 8
                    XCText {
                        objectName: "operationCostTitle"
                        xcText: "操作代价"
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                        xcFontSize: 13
                        onCenter: false
                    }
                    ObjectListModel {
                        id: costRows
                    }
                    Repeater {
                        model: costRows
                        delegate: Item_costBar {
                            objectName: "operationCostRow" + index
                            required index
                            required property string objectKey
                            width: parent.width
                            z: -index
                            modelData: costRows.value(objectKey)
                            listShift: costRemoval.shiftFor(index)
                            onDeletionStarted: root.costDeleting = true
                            onDeleteClicked: costRemoval.begin(index, height + costColumn.spacing)
                            onUpdateData: root.edited()
                        }
                    }
                    TextButton {
                        transform: Translate {
                            y: -costRemoval.offset
                        }
                        text: "＋ 添加代价"
                        height: 32
                        radius: 6
                        textSize: 13
                        textColor: Colors.banned
                        onClicked: root.addCost()
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            z: 1000
            visible: root.deleting || root.costDeleting
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onVisibleChanged: if (visible)
                forceActiveFocus()
            onWheel: function (event) {
                event.accepted = true;
            }
            Keys.onPressed: function (event) {
                event.accepted = true;
            }
            Keys.onReleased: function (event) {
                event.accepted = true;
            }
        }
    }
}
