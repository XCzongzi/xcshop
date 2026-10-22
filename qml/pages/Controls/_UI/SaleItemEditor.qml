import QtQuick
import xcshop

ContentSurface {
    id: root

    property int itemIndex: -1
    property int itemCount: 0
    property bool preview: false
    property bool expanded: true
    property string itemPath: ""
    readonly property int headerHeight: 44
    readonly property string itemTitle: {
        var prefix = "在售物品[" + (itemIndex + 1) + "]"
        var element = Global.parseElementPath(itemPath)
        if (!element)
            return prefix
        return prefix + "：" + element.name + " | " + element.relativePath
    }

    signal moveUpRequested(int index)
    signal moveDownRequested(int index)
    signal deleteRequested(int index)
    signal previewChangeRequested(int index, bool checked)
    signal itemChangeRequested(int index, string filePath)
    signal filterChangeRequested(int index, string scoreboardName,
                                 string targetName, string scoreRange)
    signal macrosChangeRequested(int index, var macros)

    implicitHeight: headerHeight + (expanded ? editorColumn.height + 12 : 0)
    height: implicitHeight
    clip: true

    Behavior on height {
        NumberAnimation { duration: 150 / Global.animationSpeed; easing.type: Easing.OutCubic }
    }

    function syncData(data) {
        if (!data)
            return
        previewCheckBox.checked = root.preview
        itemPath = typeof data.element === "string" ? data.element : ""
        itemSelection.setElement(itemPath, false)
        var filter = data.filter && typeof data.filter === "object"
                ? data.filter : ({})
        scoreboardFilter.setValues(filter.scoreboard, filter.target, filter.score)
        macroEditor.setMacros(data.macros)
    }

    onPreviewChanged: previewCheckBox.checked = root.preview

    Rectangle {
        id: header
        width: parent.width
        height: root.headerHeight
        radius: root.radius
        color: headerMouse.containsMouse
               ? Colors.changeA(Colors.fired, 0.36)
               : Colors.changeA(Colors.background, 0.20)

        Behavior on color { ColorAnimation { duration: 120 / Global.animationSpeed } }

        XCText {
            id: expandMark
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.expanded ? "▾" : "▸"
            xcFontSize: 14
            boldFont: false
            onCenter: false
            textColor: Colors.changeA(Colors.text, 0.72)
        }

        XCText {
            anchors.left: expandMark.right
            anchors.leftMargin: 7
            anchors.right: moveUpButton.left
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.itemTitle
            xcFontSize: 12
            onCenter: false
            elide: Text.ElideMiddle
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }

        TextButton {
            id: moveUpButton
            z: 2
            anchors.right: moveDownButton.left
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 6
            text: "↑"
            textSize: 15
            boldFont: false
            enabled: root.itemIndex > 0
            buttonColor: Colors.changeA(Colors.text, 0.04)
            firedColor: Colors.changeA(Colors.fired, 0.62)
            pressedColor: Colors.changeA(Colors.border, 0.55)
            onClicked: root.moveUpRequested(root.itemIndex)
        }

        TextButton {
            id: moveDownButton
            z: 2
            anchors.right: deleteButton.left
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 6
            text: "↓"
            textSize: 15
            boldFont: false
            enabled: root.itemIndex >= 0 && root.itemIndex < root.itemCount - 1
            buttonColor: Colors.changeA(Colors.text, 0.04)
            firedColor: Colors.changeA(Colors.fired, 0.62)
            pressedColor: Colors.changeA(Colors.border, 0.55)
            onClicked: root.moveDownRequested(root.itemIndex)
        }

        TextButton {
            id: deleteButton
            z: 2
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 6
            text: "×"
            textSize: 17
            boldFont: false
            enabled: root.itemCount > 0
            buttonColor: Colors.changeA(Colors.text, 0.04)
            firedColor: Colors.changeA(Colors.error, 0.22)
            pressedColor: Colors.changeA(Colors.error, 0.34)
            onClicked: root.deleteRequested(root.itemIndex)
        }
    }

    Column {
        id: editorColumn
        visible: root.expanded
        x: 10
        y: root.headerHeight + 10
        width: parent.width - 20
        spacing: 10

        XCCheckBox {
            id: previewCheckBox
            width: parent.width
            text: "在预览槽中显示"
            checked: false
            onToggled: function(checked) {
                root.previewChangeRequested(root.itemIndex, checked)
            }
        }

        Column {
            width: parent.width
            spacing: 6

            XCText {
                width: parent.width
                xcText: "出售的物品"
                xcFontSize: 12
                boldFont: false
                onCenter: false
                textColor: Colors.changeA(Colors.text, 0.82)
            }

            ElementSelectionCompact {
                id: itemSelection
                width: parent.width
                selectionId: "item"
                onElementSelected: function(filePath) {
                    root.itemPath = filePath
                    root.itemChangeRequested(root.itemIndex, filePath)
                }
                onSelectionCleared: {
                    root.itemPath = ""
                    root.itemChangeRequested(root.itemIndex, "")
                }
            }
        }

        ScoreboardFilter {
            id: scoreboardFilter
            width: parent.width
            onFilterEdited: function(scoreboardName, targetName, scoreRange) {
                root.filterChangeRequested(root.itemIndex, scoreboardName,
                                           targetName, scoreRange)
            }
        }

        MacroParameterEditor {
            id: macroEditor
            width: parent.width
            onMacrosEdited: function(macros) {
                root.macrosChangeRequested(root.itemIndex, macros)
            }
        }
    }
}
