pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PopupFrame {
    id: root
    dialogWidth: 540
    dialogHeight: 330

    title: "编辑商店"
    property var shop: ({})
    property var containerOptions: []
    property var existingRegistrationNames: []
    property string validationMessage: ""

    onAboutToOpen: {
        nameField.text = shop && shop.registrationName ? String(shop.registrationName) : ""
        containerChoice.value = shop && shop.containerType ? String(shop.containerType) : ""
        validationMessage = ""
        Qt.callLater(function() {
            nameField.forceActiveFocus()
            nameField.selectAll()
        })
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
        if (!containerChoice.value.length) {
            validationMessage = "请选择容器类型"
            return
        }
        close({
            "registrationName": registrationName,
            "containerType": containerChoice.value
        })
    }

    Keys.onEscapePressed: close(null)

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

    XCComboBox {
        id: containerChoice
        objectName: "shopContainerChoice"
        x: 24
        y: 232
        width: parent.width - 48
        height: 36
        options: root.containerOptions
        onValueActivated: function(value) { containerChoice.value = value; root.validationMessage = "" }
    }

    XCText {
        x: 24
        y: 278
        width: parent.width - root.actionWidth - 68
        xcText: root.validationMessage
        visible: root.validationMessage.length > 0
        onCenter: false
        xcFontSize: 10
        boldFont: false
        textColor: Colors.error
        elide: Text.ElideRight
    }
    actions: [
        ActionButton {
            text: "取消"
            onClicked: root.close(null)
        },
        ActionButton {
            primary: true

            text: "保存"
            onClicked: root.submit()
        }
    ]
}
