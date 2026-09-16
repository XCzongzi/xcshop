import QtQuick
import xcshop

Item {
    id: root

    property int index: -1
    property var modelData: ({})
    property bool nearest: false
    property bool deleting: false
    property int deletionIndex: -1

    signal deleteClicked()
    signal deleteAnimFinishied(int currentIndex)
    signal updateData()

    width: 500
    height: 48
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
                root.deleteAnimFinishied(root.deletionIndex)
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
            id: costSelection
            selectionId: "cost"
            width: parent.width - 32 - parent.spacing * 2 - costAmount.width
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
            id: costAmount
            highlightMacros: true
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(32, contentWidth + leftPadding + rightPadding)
            horizontalAlignment: TextInput.AlignHCenter
            text: root.modelData.amount
            onEditingFinished: {
                root.modelData.amount = text
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

    Component.onCompleted: {
        costSelection.setElement(root.modelData.element, false)
    }
}
