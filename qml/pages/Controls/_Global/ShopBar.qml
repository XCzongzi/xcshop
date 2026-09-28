pragma ComponentBehavior: Bound
import QtQuick
import xcshop

ContentBar {
    id: root

    property var shops: []
    property var containerOptions: []
    property string feedbackMessage: ""
    property bool feedbackIsError: false
    property string newElementPath: ""

    signal addRequested(var shop)
    signal updateRequested(int index, var changes)
    signal deleteRequested(int index)
    signal locateRequested(string filePath)

    title: "商店"
    subtitle: shops.length + " 个已注册商店"
    contentHeight: 400
    expanded: true

    function registrationNameExists(name, ignoredIndex) {
        for (var i = 0; i < shops.length; ++i) {
            if (i !== ignoredIndex && String(shops[i].registrationName) === name)
                return true
        }
        return false
    }

    function submitNewShop() {
        var registrationName = newName.text.trim()
        if (!newElementPath.length) {
            feedbackMessage = "请选择要注册的 UI 元素"
            feedbackIsError = true
            return
        }
        if (!/^[a-z0-9_.-]+$/.test(registrationName)) {
            feedbackMessage = "注册名只能包含小写字母、数字、下划线、点和连字符"
            feedbackIsError = true
            return
        }
        if (registrationNameExists(registrationName, -1)) {
            feedbackMessage = "注册名已存在"
            feedbackIsError = true
            return
        }
        if (!newContainer.currentValue.length) {
            feedbackMessage = "请选择容器类型"
            feedbackIsError = true
            return
        }
        addRequested({
            "element": Global.projectRelativeElementPath(newElementPath),
            "registrationName": registrationName,
            "containerType": newContainer.currentValue
        })
    }

    function clearNewShop() {
        newElementPath = ""
        newUi.clearElement(false)
        newName.text = ""
        newContainer.currentValue = containerOptions.length ? containerOptions[0].value : ""
    }

    function browseUiElement() {
        uiFileDialog.currentFolder = "file:" + Global.project_location + "/UI"
        uiFileDialog.openXC(false, "shop-ui")
    }

    function submitNameEdit(index, field) {
        var name = field.text.trim()
        if (!/^[a-z0-9_.-]+$/.test(name)) {
            field.text = shops[index].registrationName
            feedbackMessage = "注册名格式不正确"
            feedbackIsError = true
            return
        }
        if (registrationNameExists(name, index)) {
            field.text = shops[index].registrationName
            feedbackMessage = "注册名已存在"
            feedbackIsError = true
            return
        }
        if (name !== shops[index].registrationName)
            updateRequested(index, { "registrationName": name })
    }

    Item {
        x: 16
        y: 62
        width: parent.width - 32
        height: parent.height - y - 8

        XCText {
            id: registeredTitle
            xcText: "已注册的商店"
            onCenter: false
            xcFontSize: 14
        }

        Row {
            id: tableHeader
            y: 21
            width: parent.width
            height: 18
            spacing: 10

            readonly property real usableWidth: width - spacing * 3 - 56
            XCText { width: tableHeader.usableWidth * 0.38; xcText: "UI 元素"; onCenter: false; xcFontSize: 11; boldFont: false; textColor: Colors.banned }
            XCText { width: tableHeader.usableWidth * 0.27; xcText: "注册名"; onCenter: false; xcFontSize: 11; boldFont: false; textColor: Colors.banned }
            XCText { width: tableHeader.usableWidth * 0.35; xcText: "容器类型"; onCenter: false; xcFontSize: 11; boldFont: false; textColor: Colors.banned }
            Item { width: 56; height: 1 }
        }

        ListView {
            id: shopList
            y: tableHeader.y + tableHeader.height
            width: parent.width
            height: Math.max(0, newShopArea.y - y - 7)
            clip: true
            spacing: 2
            model: root.shops

            delegate: Rectangle {
                id: shopRow
                required property int index
                required property var model
                readonly property var shop: model.modelData
                readonly property real usableWidth: width - rowContent.spacing * 3 - deleteButton.width

                width: shopList.width
                height: 46
                radius: 7
                color: index % 2
                       ? Colors.changeA(Colors.background, 0.22)
                       : Colors.changeA(Colors.foreground, 0.22)

                Row {
                    id: rowContent
                    anchors.fill: parent
                    spacing: 10

                    Item {
                        width: shopRow.usableWidth * 0.38
                        height: parent.height

                        XCText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            xcText: shopRow.shop.element
                            onCenter: false
                            xcFontSize: 12
                            boldFont: false
                            underlineFont: uiHover.hovered
                            textColor: uiHover.hovered ? Colors.border : Colors.text
                            elide: Text.ElideMiddle
                        }
                        HoverHandler { id: uiHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: root.locateRequested(shopRow.shop.element)
                        }
                    }

                    XCTextField {
                        width: shopRow.usableWidth * 0.27
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        text: shopRow.shop.registrationName
                        font.pixelSize: 12
                        onEditingFinished: root.submitNameEdit(shopRow.index, this)
                    }

                    GlobalChoiceBox {
                        width: shopRow.usableWidth * 0.35
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        compact: true
                        options: root.containerOptions
                        currentValue: shopRow.shop.containerType
                        onValueActivated: function(value) {
                            root.updateRequested(shopRow.index, { "containerType": value })
                        }
                    }

                    TextButton {
                        id: deleteButton
                        width: 56
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 6
                        text: "删除"
                        textSize: 11
                        buttonColor: Colors.changeA(Colors.error, 0.14)
                        firedColor: Colors.changeA(Colors.error, 0.25)
                        pressedColor: Colors.changeA(Colors.error, 0.36)
                        onClicked: root.deleteRequested(shopRow.index)
                    }
                }
            }

            XCText {
                visible: root.shops.length === 0
                anchors.centerIn: parent
                xcText: "暂无已注册商店"
                xcFontSize: 12
                boldFont: false
                textColor: Colors.banned
            }
        }

        Item {
            id: newShopArea
            anchors.bottom: parent.bottom
            width: parent.width
            height: 72

            ElementSelectionCompact {
                id: newUi
                x: 0
                width: parent.width - browseUiButton.width - 7
                height: 32
                selectionId: "UI"
                onElementSelected: function(filePath) {
                    root.newElementPath = filePath
                    root.feedbackMessage = ""
                }
                onSelectionCleared: root.newElementPath = ""
            }

            TextButton {
                id: browseUiButton
                anchors.right: parent.right
                y: newUi.y + 2
                width: 54
                height: 28
                radius: 7
                text: "浏览"
                textSize: 10
                buttonColor: Colors.changeA(Colors.pressed, 0.72)
                onClicked: root.browseUiElement()
            }

            Row {
                id: createFields
                y: 36
                width: parent.width
                height: 28
                spacing: 6

                XCTextField {
                    id: newName
                    width: Math.max(92, parent.width * 0.30)
                    height: parent.height
                    placeholderText: "注册名"
                    font.pixelSize: 11
                    onTextEdited: root.feedbackMessage = ""
                    onAccepted: root.submitNewShop()
                }

                GlobalChoiceBox {
                    id: newContainer
                    width: Math.max(118, parent.width - newName.width - addButton.width - parent.spacing * 2)
                    height: parent.height
                    compact: true
                    options: root.containerOptions
                    currentValue: root.containerOptions.length ? root.containerOptions[0].value : ""
                }

                TextButton {
                    id: addButton
                    width: 58
                    height: parent.height
                    radius: 7
                    text: "注册"
                    textSize: 10
                    buttonColor: Colors.changeA(Colors.border, 0.72)
                    firedColor: Colors.changeA(Colors.border, 0.90)
                    pressedColor: Colors.border
                    textColor: "#1b1b1b"
                    onClicked: root.submitNewShop()
                }
            }

            XCText {
                y: 63
                width: parent.width
                xcText: root.feedbackMessage
                visible: root.feedbackMessage.length > 0
                onCenter: false
                xcFontSize: 9
                boldFont: false
                textColor: root.feedbackIsError ? Colors.error : Colors.border
            }
        }
    }

    XCFileDialog {
        id: uiFileDialog
        nameFilters: ["XCShop UI 元素 (*.xcseUI)"]
        onAccepted: newUi.setElement(selectedFile.toString(), true)
    }
}
