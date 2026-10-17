pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    anchors.fill: parent
    focus: true

    property string title: "编辑商店"
    property var shop: ({})
    property var containerOptions: []
    property var existingRegistrationNames: []
    property string validationMessage: ""
    property var result: null

    signal closed(var result)

    function open() {
        scrim.opacity = 0
        dialog.opacity = 0
        dialog.scale = 0.97
        nameField.text = shop && shop.registrationName ? String(shop.registrationName) : ""
        containerChoice.currentValue = shop && shop.containerType ? String(shop.containerType) : ""
        validationMessage = ""
        openAnimation.restart()
        Qt.callLater(function() {
            nameField.forceActiveFocus()
            nameField.selectAll()
        })
    }

    function close(closeResult) {
        if (closeAnimation.running)
            return
        result = closeResult === undefined ? null : closeResult
        closeAnimation.restart()
    }

    function submit() {
        var registrationName = nameField.text.trim()
        if (!/^[a-z0-9_.-]+$/.test(registrationName)) {
            validationMessage = "注册名只能包含小写字母、数字、下划线、点和连字符"
            return
        }
        if (existingRegistrationNames.indexOf(registrationName) >= 0) {
            validationMessage = "注册名已存在"
            return
        }
        if (!containerChoice.currentValue.length) {
            validationMessage = "请选择容器类型"
            return
        }
        close({
            "registrationName": registrationName,
            "containerType": containerChoice.currentValue
        })
    }

    Keys.onEscapePressed: close(null)

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        MouseArea { anchors.fill: parent; hoverEnabled: true }
    }

    Rectangle {
        id: dialog
        width: Math.min(540, Math.max(380, root.width - 48))
        height: 330
        anchors.centerIn: parent
        radius: 15
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.985)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.12)
        transformOrigin: Item.Center
        opacity: 0

        layer.enabled: true
        layer.effect: XCShadow {
            shadowColor: "#a8000000"
            shadowBlur: 0.85
            shadowVerticalOffset: 10
        }

        Rectangle { width: parent.width; height: 5; radius: 15; color: Colors.border }

        XCText {
            x: 24
            y: 25
            width: parent.width - 48
            xcText: root.title
            onCenter: false
            xcFontSize: 21
        }

        Rectangle {
            x: 24
            y: 65
            width: parent.width - 48
            height: 1
            color: Colors.changeA(Colors.text, 0.10)
        }

        Image {
            id: uiIcon
            x: 24
            y: 86
            width: 25
            height: 25
            source: "qrc:/assets/gui/element/UI.png"
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
        }

        XCText {
            x: uiIcon.x + uiIcon.width + 9
            y: 82
            width: parent.width - x - 24
            xcText: "关联 UI 元素"
            onCenter: false
            xcFontSize: 10
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.62)
        }

        XCText {
            x: uiIcon.x + uiIcon.width + 9
            y: 99
            width: parent.width - x - 24
            xcText: root.shop && root.shop.element ? String(root.shop.element) : "未连接"
            onCenter: false
            xcFontSize: 12
            boldFont: false
            elide: Text.ElideMiddle
        }

        XCText {
            x: 24
            y: 139
            xcText: "注册名"
            onCenter: false
            xcFontSize: 11
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.72)
        }

        XCTextField {
            id: nameField
            x: 24
            y: 160
            width: parent.width - 48
            height: 36
            placeholderText: "注册名"
            onTextEdited: root.validationMessage = ""
            onAccepted: root.submit()
        }

        XCText {
            x: 24
            y: 211
            xcText: "容器类型"
            onCenter: false
            xcFontSize: 11
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.72)
        }

        GlobalChoiceBox {
            id: containerChoice
            x: 24
            y: 232
            width: parent.width - 48
            height: 36
            options: root.containerOptions
            onValueActivated: root.validationMessage = ""
        }

        XCText {
            x: 24
            y: 278
            width: parent.width - buttonRow.width - 68
            xcText: root.validationMessage
            visible: root.validationMessage.length > 0
            onCenter: false
            xcFontSize: 10
            boldFont: false
            textColor: Colors.error
            elide: Text.ElideRight
        }

        Row {
            id: buttonRow
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 8

            TextButton {
                text: "取消"
                height: 34
                radius: 7
                textSize: 13
                widthBorderSize: 12
                buttonColor: Colors.changeA(Colors.pressed, 0.82)
                onClicked: root.close(null)
            }
            TextButton {
                text: "保存"
                height: 34
                radius: 7
                textSize: 13
                widthBorderSize: 13
                buttonColor: Colors.changeA(Colors.border, 0.72)
                firedColor: Colors.changeA(Colors.border, 0.88)
                pressedColor: Colors.border
                textColor: "#1b1b1b"
                onClicked: root.submit()
            }
        }
    }

    ParallelAnimation {
        id: openAnimation
        PropertyAnimation { target: scrim; property: "opacity"; to: 0.42; duration: 180 / Global.animationSpeed; easing.type: Easing.OutCubic }
        PropertyAnimation { target: dialog; property: "opacity"; to: 1; duration: 180 / Global.animationSpeed; easing.type: Easing.OutCubic }
        PropertyAnimation { target: dialog; property: "scale"; to: 1; duration: 220 / Global.animationSpeed; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: closeAnimation
        PropertyAnimation { target: scrim; property: "opacity"; to: 0; duration: 150 / Global.animationSpeed; easing.type: Easing.InCubic }
        PropertyAnimation { target: dialog; property: "opacity"; to: 0; duration: 130 / Global.animationSpeed; easing.type: Easing.InCubic }
        PropertyAnimation { target: dialog; property: "scale"; to: 0.97; duration: 150 / Global.animationSpeed; easing.type: Easing.InCubic }
        onFinished: root.closed(root.result)
    }
}
