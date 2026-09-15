import QtQuick
import xcshop

// A UI connection row with the same removal animation used by Item's cost rows.
Item {
    id: root

    property int index: -1
    property var modelData: ({})
    property bool nearest: false
    property bool deleting: false
    property int deletionIndex: -1

    signal deleteClicked()
    signal deleteAnimFinished(int currentIndex)
    signal updateData()

    implicitHeight: 48
    height: implicitHeight
    enabled: opacity > 0.01

    function afterDeleting(offset, currentIndex) {
        deletionIndex = currentIndex
        shiftAnimation.to = -offset
        shiftAnimation.restart()
    }

    NumberAnimation {
        id: shiftAnimation
        target: frame
        property: "y"
        duration: 120 / Global.animationSpeed
        easing.type: Easing.InCubic
        onFinished: {
            frame.y = 0
            if (root.nearest) {
                root.nearest = false
                root.deleteAnimFinished(root.deletionIndex)
            }
        }
    }

    Row {
        id: frame
        width: parent.width
        height: parent.height
        spacing: 4

        ImageButton {
            anchors.verticalCenter: parent.verticalCenter
            freeze: root.deleting
            btnSize: 32
            radius: 8
            btnbackground: Colors.changeA(Colors.error, 0.72)
            btnfired: Colors.changeA(Colors.error, 0.90)
            btnpressed: Colors.error
            onClicked: deleteAnimation.start()
        }

        ElementSelectionCompact {
            id: uiSelection
            width: parent.width - 32 - parent.spacing * 2 - valueInput.width
            selectionId: "ui"
            onElementSelected: function(filePath) {
                root.modelData.element = filePath
                root.updateData()
            }
            onSelectionCleared: {
                root.modelData.element = ""
                root.updateData()
            }
        }

        XCTextField {
            id: valueInput
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(38, contentWidth + leftPadding + rightPadding)
            horizontalAlignment: TextInput.AlignHCenter
            placeholderText: "值"
            text: root.modelData.value === undefined ? "1" : root.modelData.value
            onEditingFinished: {
                root.modelData.value = text
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
        onStarted: root.deleting = true
        onFinished: {
            root.opacity = 0
            root.deleteClicked()
        }
    }

    Component.onCompleted: uiSelection.setElement(root.modelData.element, false)
}
