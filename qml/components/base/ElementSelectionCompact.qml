import QtQuick
import xcshop

ElementSelectionBase {
    id: root

    Item {
        id: typeSummary
        visible: root.width >= 250
        x: 7
        width: typeIcon.width + 7 + typeText.width + 10
        height: parent.height

        ThemedIcon {
            id: typeIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            iconSource: root.elementIconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
        }

        XCText {
            id: typeText
            anchors.left: typeIcon.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.selectionTypeName
            xcFontSize: 11
            boldFont: false
            textColor: Colors.text
        }
    }

    Rectangle {
        id: typeSeparator
        visible: typeSummary.visible
        anchors.left: typeSummary.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Colors.changeA(Colors.outline, 0.14)
    }

    Item {
        id: selectionSummary
        anchors.left: typeSeparator.visible ? typeSeparator.right : parent.left
        anchors.leftMargin: 9
        anchors.right: selectButton.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        XCText {
            id: placeholder
            visible: !root.hasSelection
            width: Math.min(implicitWidth, parent.width)
            xcText: root.placeholderText
            xcFontSize: 12
            boldFont: false
            onCenter: false
            onVCenter: true
            textColor: root.highlighted ? Colors.changeA(Colors.accentText, 0.92) : Colors.banned
        }

        XCText {
            id: selectedName
            visible: root.hasSelection
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Math.max(72, parent.width * 0.42))
            xcText: root.selectedElementName
            xcFontSize: 12
            onCenter: false
            underlineFont: root.connectedElementHovered
            textColor: root.connectedElementHovered ? Colors.accentText : Colors.text
        }

        XCText {
            id: pathSeparator
            visible: root.hasSelection
            anchors.left: selectedName.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            xcText: "|"
            xcFontSize: 12
            boldFont: false
            onCenter: false
            textColor: Colors.changeA(Colors.text, 0.35)
        }

        XCText {
            id: selectedPath
            visible: root.hasSelection
            anchors.left: pathSeparator.right
            anchors.leftMargin: 7
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            xcText: root.selectedElementDisplayPath
            xcFontSize: 11
            boldFont: false
            onCenter: false
            elide: Text.ElideLeft
            underlineFont: root.connectedElementHovered
            textColor: root.connectedElementHovered ? Colors.changeA(Colors.accentText, 0.86)
                                                : Colors.banned
        }

        HoverHandler {
            id: selectedElementHover
            enabled: root.hasSelection
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.connectedElementHovered = hovered
        }

        TapHandler {
            enabled: root.hasSelection
            acceptedButtons: Qt.LeftButton
            onTapped: root.openConnectedElement()
        }
    }

    ActionButton {
        id: selectButton
        primary: true
        anchors.right: clearButton.visible ? clearButton.left : parent.right
        anchors.rightMargin: clearButton.visible ? 5 : 7
        anchors.verticalCenter: parent.verticalCenter
        width: root.waitingForSelection ? 56 : 50
        height: 28
        radius: 6
        text: root.waitingForSelection ? "取消" : "选择"
        textSize: 11
        boldFont: false
        onClicked: {
            if (root.waitingForSelection)
                root.cancelElementSelection()
            else
                root.requestElementSelection()
        }
    }

    TextButton {
        id: clearButton
        visible: root.hasSelection
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 6
        text: "×"
        textSize: 17
        boldFont: false
        textColor: Colors.banned
        buttonColor: Colors.changeA(Colors.text, 0.035)
        firedColor: Colors.changeA(Colors.error, 0.18)
        pressedColor: Colors.changeA(Colors.error, 0.28)
        onClicked: root.clearElement(true)
    }
}
