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
    signal editRequested(int index)
    signal deleteRequested(int index)
    signal locateRequested(string filePath)

    title: "商店"
    subtitle: shops.length + " 个已注册商店"
    contentHeight: 400
    expanded: true
    padding: 20

    function registrationNameExists(name) {
        for (var i = 0; i < shops.length; ++i) {
            if (String(shops[i].registrationName) === name)
                return true
        }
        return false
    }

    function containerLabel(value) {
        for (var i = 0; i < containerOptions.length; ++i) {
            if (String(containerOptions[i].value) === String(value))
                return String(containerOptions[i].label)
        }
        return value ? String(value) : "未设置"
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
        if (registrationNameExists(registrationName)) {
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

    Item {
        x: root.padding
        y: 76
        width: parent.width - root.padding * 2
        height: parent.height - y - 20

        XCText {
            id: registeredTitle
            xcText: "已注册的商店"
            onCenter: false
            xcFontSize: 13
        }

        ListView {
            id: shopList
            y: 30
            width: parent.width
            height: Math.max(0, newShopArea.y - y - 9)
            clip: true
            spacing: 4
            model: root.shops

            delegate: Rectangle {
                id: shopRow
                required property int index
                required property var model
                readonly property var shop: model.modelData

                width: shopList.width
                height: 54
                radius: 7
                color: rowHover.hovered
                       ? Colors.changeA(Colors.fired, 0.26)
                       : (index % 2 ? Colors.changeA(Colors.background, 0.22)
                                    : Colors.changeA(Colors.foreground, 0.22))

                Behavior on color { ColorAnimation { duration: 120 / Global.animationSpeed } }

                XCText {
                    id: shopName
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 7
                    anchors.right: containerText.left
                    anchors.rightMargin: 8
                    xcText: shopRow.shop.registrationName || "未命名商店"
                    onCenter: false
                    xcFontSize: 12
                    elide: Text.ElideRight
                }

                XCText {
                    id: containerText
                    anchors.baseline: shopName.baseline
                    anchors.right: actions.left
                    anchors.rightMargin: 12
                    width: Math.min(implicitWidth, Math.max(72, shopRow.width * 0.27))
                    xcText: root.containerLabel(shopRow.shop.containerType)
                    onCenter: false
                    horizontalAlignment: Text.AlignRight
                    xcFontSize: 10
                    boldFont: false
                    textColor: Colors.banned
                    elide: Text.ElideRight
                }

                Item {
                    id: uiLink
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: actions.left
                    anchors.rightMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    height: 16

                    Image {
                        id: uiIcon
                        width: 15
                        height: 15
                        anchors.verticalCenter: parent.verticalCenter
                        source: "qrc:/assets/gui/element/UI.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        mipmap: false
                    }

                    XCText {
                        anchors.left: uiIcon.right
                        anchors.leftMargin: 6
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        xcText: shopRow.shop.element || "未连接 UI 元素"
                        onCenter: false
                        xcFontSize: 10
                        boldFont: false
                        underlineFont: uiHover.hovered
                        textColor: uiHover.hovered ? Colors.border : Colors.banned
                        elide: Text.ElideMiddle
                    }

                    HoverHandler {
                        id: uiHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.locateRequested(shopRow.shop.element)
                    }
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    TextButton {
                        width: 43
                        height: 28
                        radius: 6
                        text: "编辑"
                        textSize: 10
                        buttonColor: Colors.changeA(Colors.pressed, 0.72)
                        onClicked: root.editRequested(shopRow.index)
                    }

                    TextButton {
                        width: 43
                        height: 28
                        radius: 6
                        text: "删除"
                        textSize: 10
                        buttonColor: Colors.changeA(Colors.error, 0.14)
                        firedColor: Colors.changeA(Colors.error, 0.25)
                        pressedColor: Colors.changeA(Colors.error, 0.36)
                        onClicked: root.deleteRequested(shopRow.index)
                    }
                }

                HoverHandler { id: rowHover }
            }

            XCText {
                visible: root.shops.length === 0
                anchors.centerIn: parent
                xcText: "暂无已注册商店"
                xcFontSize: 11
                boldFont: false
                textColor: Colors.banned
            }
        }

        Item {
            id: newShopArea
            anchors.bottom: parent.bottom
            width: parent.width
            height: 136

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.changeA(Colors.text, 0.09)
            }

            XCText {
                y: 12
                xcText: "注册新商店"
                onCenter: false
                xcFontSize: 12
            }

            ElementSelectionCompact {
                id: newUi
                y: 36
                width: parent.width
                height: 34
                selectionId: "UI"
                onElementSelected: function(filePath) {
                    root.newElementPath = filePath
                    root.feedbackMessage = ""
                }
                onSelectionCleared: root.newElementPath = ""
            }

            Row {
                id: createFields
                y: 80
                width: parent.width
                height: 30
                spacing: 8

                XCTextField {
                    id: newName
                    width: Math.max(64, parent.width * 0.30)
                    height: parent.height
                    placeholderText: "注册名"
                    font.pixelSize: 11
                    onTextEdited: root.feedbackMessage = ""
                    onAccepted: root.submitNewShop()
                }

                GlobalChoiceBox {
                    id: newContainer
                    width: Math.max(64, parent.width - newName.width - addButton.width - parent.spacing * 2)
                    height: parent.height
                    compact: true
                    options: root.containerOptions
                    currentValue: root.containerOptions.length ? root.containerOptions[0].value : ""
                    onValueActivated: root.feedbackMessage = ""
                }

                TextButton {
                    id: addButton
                    width: 48
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
                y: 120
                width: parent.width
                xcText: root.feedbackMessage
                visible: root.feedbackMessage.length > 0
                onCenter: false
                xcFontSize: 9
                boldFont: false
                textColor: root.feedbackIsError ? Colors.error : Colors.border
                elide: Text.ElideRight
            }
        }
    }
}
