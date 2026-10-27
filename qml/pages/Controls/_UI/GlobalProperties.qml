import QtQuick
import xcshop

Item {
    id: root
    width: parent.width
    height: parent.height - 16
    y: 16

    property var uiPage: null

    Column {
        width: parent.width
        spacing: 14

        XCText {
            width: parent.width
            xcText: "容器设置"
            onCenter: false
            xcFontSize: 15
        }

        Rectangle {
            width: parent.width
            height: containerTypeLabel.height + changeTypeButton.height + 20
            radius: 8
            color: Colors.changeA(Colors.background, 0.42)
            border.width: 1
            border.color: Colors.changeA(Colors.outline, 0.10)

            XCText {
                id: containerTypeLabel
                x: 10
                y: 9
                width: parent.width - x * 2
                xcText: "当前界面：" + (root.uiPage
                                        ? root.uiPage.currentContainerTypeLabel : "未选择")
                onCenter: false
                xcFontSize: 13
                boldFont: false
                elide: Text.ElideRight
            }

            TextButton {
                id: changeTypeButton
                x: 10
                y: containerTypeLabel.y + containerTypeLabel.height + 5
                height: 30
                radius: 6
                text: "修改界面类型"
                textSize: 12
                widthBorderSize: 9
                enabled: root.uiPage && root.uiPage.dataLoaded
                buttonColor: Colors.changeA(Colors.card, 0.55)
                firedColor: Colors.changeA(Colors.fired, 0.55)
                pressedColor: Colors.changeA(Colors.border, 0.68)
                onClicked: root.uiPage.beginContainerTypeChange()
            }
        }

        XCText {
            width: parent.width
            xcText: "自定义名称"
            onCenter: false
            xcFontSize: 13
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.82)
        }

        XCTextField {
            id: customNameInput
            width: parent.width
            height: 34
            enabled: root.uiPage && root.uiPage.dataLoaded
            placeholderText: "留空则使用默认名称"
            text: root.uiPage ? root.uiPage.customName : ""
            onEditingFinished: {
                if (root.uiPage)
                    root.uiPage.setCustomName(text)
            }
        }

        XCText {
            width: parent.width
            xcText: "打开时触发的指令"
            onCenter: false
            xcFontSize: 13
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.82)
        }

        XCTextField {
            id: openCommandInput
            width: parent.width
            height: 34
            enabled: root.uiPage && root.uiPage.dataLoaded
            placeholderText: "例如：say 已打开商店"
            text: root.uiPage ? root.uiPage.openCommand : ""
            onEditingFinished: {
                if (root.uiPage)
                    root.uiPage.setOpenCommand(text)
            }
        }
    }

    Connections {
        target: root.uiPage
        function onCustomNameChanged() {
            if (!customNameInput.activeFocus)
                customNameInput.text = root.uiPage.customName
        }
        function onOpenCommandChanged() {
            if (!openCommandInput.activeFocus)
                openCommandInput.text = root.uiPage.openCommand
        }
    }
}
