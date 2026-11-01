import QtQuick
import xcshop

Item {
    id: root
    property int index: -1
    property var modelData: ({})
    readonly property var rowData: modelData || ({})
    property string selectionType: ""
    property string valueKey: "value"
    property string defaultValue: "1"
    property string valuePlaceholder: ""
    property bool highlightMacros: false
    property bool deleting: false
    property real listShift: 0
    signal deleteClicked
    signal deletionStarted
    signal updateData
    implicitHeight: 48
    height: implicitHeight
    enabled: !deleting && opacity > 0.01

    Row {
        id: frame
        width: parent.width
        height: parent.height
        spacing: 4
        transform: Translate {
            y: root.listShift
        }
        ImageButton {
            objectName: "removeCostButton"
            anchors.verticalCenter: parent.verticalCenter
            btnSize: 32
            imgSize: 18
            imageSource: "qrc:/assets/gui/controls/delete.svg"
            radius: 8
            btnbackground: Colors.changeA(Colors.error, 0.72)
            btnfired: Colors.changeA(Colors.error, 0.90)
            btnpressed: Colors.error
            onClicked: deleteAnimation.start()
        }
        ElementSelectionCompact {
            id: selection
            selectionId: root.selectionType
            width: Math.max(0, parent.width - 32 - parent.spacing * 2 - valueInput.width)
            onElementSelected: function (filePath) {
                root.rowData.element = filePath
                root.updateData()
            }
            onSelectionCleared: {
                root.rowData.element = ""
                root.updateData()
            }
        }
        XCTextField {
            id: valueInput
            objectName: "connectionValueInput"
            highlightMacros: root.highlightMacros
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Math.max(64, contentWidth + leftPadding + rightPadding), root.width * 0.42)
            horizontalAlignment: TextInput.AlignHCenter
            placeholderText: root.valuePlaceholder
            text: root.rowData[root.valueKey] === undefined ? root.defaultValue : root.rowData[root.valueKey]
            onEditingFinished: {
                root.rowData[root.valueKey] = text
                root.updateData()
            }
        }
    }
    NumberAnimation {
        id: deleteAnimation
        target: frame
        property: "x"
        to: root.width
        duration: 200 / Global.animationSpeed
        easing.type: Easing.InCubic
        onStarted: {
            root.deleting = true
            root.deletionStarted()
        }
        onFinished: {
            root.opacity = 0
            root.deleteClicked()
        }
    }
    onRowDataChanged: if (selection)
        selection.setElement(rowData.element || "", false)
    Component.onCompleted: selection.setElement(rowData.element || "", false)
}
