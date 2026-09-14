import QtQuick
import xcshop

Item {
    id: root
    property var accentChoices: Colors.accentChoices
    property var colorChoices: [
        { id: "midnight", name: "深夜", mode: "深色", background: "#1b1d27", foreground: "#41434f", surface: "#6b6c74", text: "#ffffff" },
        { id: "cloud", name: "云白", mode: "浅色", background: "#edf2f7", foreground: "#dce5ee", surface: "#aebaca", text: "#172033" },
        { id: "slate", name: "石板", mode: "深色", background: "#202b38", foreground: "#45586c", surface: "#526b82", text: "#f3f8ff" },
        { id: "glacier", name: "冰川", mode: "浅色", background: "#eaf5fa", foreground: "#d5e8f0", surface: "#87adbf", text: "#123047" },
        { id: "violet", name: "紫雾", mode: "深色", background: "#2b2238", foreground: "#5b476d", surface: "#72588a", text: "#fff8ff" },
        { id: "lavender", name: "薰衣草", mode: "浅色", background: "#f4eff9", foreground: "#e6dcef", surface: "#b9a2c9", text: "#2c2039" },
        { id: "forest", name: "森林", mode: "深色", background: "#162d2d", foreground: "#345b58", surface: "#46756f", text: "#f3fffb" },
        { id: "mint", name: "薄荷", mode: "浅色", background: "#e9f5ef", foreground: "#d4e9de", surface: "#88b59c", text: "#17352d" },
        { id: "amber", name: "琥珀", mode: "深色", background: "#33251d", foreground: "#654c3c", surface: "#815b43", text: "#fff9f3" },
        { id: "parchment", name: "羊皮纸", mode: "浅色", background: "#fbf3e5", foreground: "#ead8bd", surface: "#c7a66f", text: "#3d2d1f" },
        { id: "rose", name: "玫瑰", mode: "深色", background: "#38232e", foreground: "#704658", surface: "#89596e", text: "#fff7f9" },
        { id: "blush", name: "樱粉", mode: "浅色", background: "#f9edf1", foreground: "#eed8e1", surface: "#c5899f", text: "#3b2430" }
    ]

    function chooseTheme(color) {
        Colors.setThemeColor(color)
        Global.saveSettings()
    }
    function isSelectedTheme(color) {
        var choice = Qt.color(color)
        return Math.abs(Colors.themeColor.r - choice.r) < 0.001
                && Math.abs(Colors.themeColor.g - choice.g) < 0.001
                && Math.abs(Colors.themeColor.b - choice.b) < 0.001
    }
    function accentForColorScheme(schemeId) {
        return Colors.accentForColorScheme(schemeId)
    }
    function backgroundTypeIndex() {
        if (Global.backgroundMode === "color") return 0
        return 1
    }
    function chooseColorScheme(schemeId) {
        Colors.applyColorScheme(schemeId)
        Global.saveSettings()
    }
    function colorSchemeData(schemeId) {
        for (var i = 0; i < colorChoices.length; ++i)
            if (colorChoices[i].id === schemeId)
                return colorChoices[i]
        return colorChoices[0]
    }

    XCFileDialog {
        id: imageFileDialog
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp)", "All files (*)"]
        onAccepted: {
            Global.backgroundImage = selectedFile.toString()
            Global.backgroundMode = "image"
            Global.saveSettings()
        }
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            width: parent.width
            spacing: 12

            SettingsPageHeader {
                width: parent.width
                title: "界面"
            }

            ContentBar {
                id: themeBar
                width: parent.width
                expanded: true
                title: "主题与配色"
                contentHeight: schemeGrid.y + schemeGrid.height + 16
                Column {
                    id: schemeGrid
                    x: 16; y: 48
                    width: parent.width - 32
                    spacing: 10

                    property int labelWidth: 36
                    property int cardWidth: 128
                    property int columnGap: 10

                    Item {
                        width: schemeGrid.width
                        height: Math.max(36, accentFlow.height)

                        Flow {
                            id: accentFlow
                            x: schemeGrid.labelWidth + schemeGrid.columnGap
                            width: parent.width - x
                            height: childrenRect.height
                            spacing: schemeGrid.columnGap

                            Repeater {
                                model: ["", root.accentChoices[0], root.accentChoices[1], root.accentChoices[3], root.accentChoices[4], root.accentChoices[2]]
                                delegate: Item {
                                    required property string modelData
                                    property bool selected: modelData.length && root.isSelectedTheme(modelData)
                                    property bool hovered: false
                                    property bool pressed: false
                                    width: schemeGrid.cardWidth; height: 36
                                    Rectangle { anchors.centerIn: parent; visible: parent.selected; width: 36; height: 36; radius: 18; color: Colors.text }
                                    Rectangle {
                                        visible: parent.modelData.length
                                        anchors.centerIn: parent; width: 30; height: 30; radius: 15; color: parent.modelData
                                        border.width: parent.selected ? 2 : 1
                                        border.color: parent.selected ? Colors.changeA(Colors.background, 0.88) : Colors.changeA(Colors.text, 0.32)
                                        scale: parent.pressed ? 0.90 : (parent.hovered && !parent.selected ? 1.10 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 120 / Global.animationSpeed } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: parent.modelData.length
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: root.chooseTheme(parent.modelData)
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: ["深色", "浅色"]
                        delegate: Item {
                            id: schemeRow
                            required property int index
                            required property string modelData
                            property int schemeRowIndex: index
                            width: schemeGrid.width
                            height: Math.max(76, paletteFlow.height)

                            XCText {
                                width: schemeGrid.labelWidth; height: 76
                                anchors.verticalCenter: parent.verticalCenter
                                xcText: modelData; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned
                            }
                            Flow {
                                id: paletteFlow
                                x: schemeGrid.labelWidth + schemeGrid.columnGap
                                width: parent.width - x
                                height: childrenRect.height
                                spacing: schemeGrid.columnGap

                                Repeater {
                                    model: 6
                                    delegate: Item {
                                        required property int index
                                    property var schemeChoice: root.colorChoices[index * 2 + schemeRow.schemeRowIndex]
                                    property bool selected: Colors.colorScheme === schemeChoice.id
                                    property bool hovered: false
                                    property bool pressed: false
                                    width: schemeGrid.cardWidth; height: 76
                                    Rectangle {
                                        anchors.centerIn: parent; width: parent.width; height: parent.height; radius: 8
                                        color: parent.schemeChoice.background
                                        border.width: parent.selected ? 2 : 1; border.color: parent.selected ? Colors.themeColor : Qt.rgba(0, 0, 0, 0.18)
                                        scale: parent.pressed ? 0.975 : (parent.hovered && !parent.selected ? 1.025 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 120 / Global.animationSpeed } }
                                        Rectangle { x: 8; y: 8; width: parent.width - 16; height: 16; radius: 4; color: parent.parent.schemeChoice.foreground }
                                        Rectangle { x: 12; y: 12; width: 34; height: 3; radius: 2; color: parent.parent.schemeChoice.text }
                                        XCText { x: 52; y: 8; width: 66; height: 16; xcText: parent.parent.schemeChoice.name; onCenter: false; xcFontSize: 11; boldFont: false; textColor: parent.parent.schemeChoice.text }
                                        Rectangle { x: 8; y: 31; width: 66; height: 34; radius: 5; color: parent.parent.schemeChoice.foreground }
                                        Rectangle { x: 13; y: 38; width: 42; height: 6; radius: 3; color: parent.parent.schemeChoice.background }
                                        Rectangle { x: 82; y: 31; width: 38; height: 16; radius: 5; color: parent.parent.schemeChoice.surface }
                                        Rectangle { x: 82; y: 53; width: 38; height: 12; radius: 4; color: parent.parent.schemeChoice.foreground }
                                        Rectangle { x: 104; y: 35; width: 12; height: 8; radius: 4; color: root.accentForColorScheme(parent.parent.schemeChoice.id) || Colors.themeColor }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.hovered = true
                                        onExited: { parent.hovered = false; parent.pressed = false }
                                        onPressed: parent.pressed = true
                                        onReleased: parent.pressed = false
                                        onClicked: root.chooseColorScheme(parent.schemeChoice.id)
                                    }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ContentBar {
                id: backgroundBar
                width: parent.width
                expanded: true
                title: "背景"
                contentHeight: blurRow.visible ? blurRow.y + blurRow.height + 16
                                                                                           : backgroundType.y + backgroundType.height + 16

                RadioGroup {
                    id: backgroundType
                    x: 16
                    y: 48
                    text: "背景类型"
                    options: ["纯色", "图片"]
                    initialOption: root.backgroundTypeIndex()
                    onClicked: {
                        Global.backgroundMode = ["color", "image"][selected]
                        Global.saveSettings()
                    }
                }
                Row {
                    id: imageRow
                    x: 16
                    y: backgroundType.y + backgroundType.height + 12
                    visible: Global.backgroundMode === "image"
                    spacing: 10
                    TextButton { text: "选择图片"; height: 32; radius: 7; textSize: 13; widthBorderSize: 10; buttonColor: Colors.pressed; onClicked: imageFileDialog.openXC(false, "background") }
                    XCText { width: Math.max(120, backgroundBar.width - 160); xcText: Global.backgroundImage.length ? Global.backgroundImage : "未选择图片"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned; elide: Text.ElideMiddle }
                }
                Row {
                    id: blurRow
                    x: 16
                    y: imageRow.y + imageRow.height + 10
                    visible: imageRow.visible
                    spacing: 10
                    XCText { id: blurLabel; xcText: "模糊强度"; onCenter: false; xcFontSize: 13; boldFont: false; width: 70 }
                    XCSlider {
                        width: Math.min(260, Math.max(0, backgroundBar.width - blurRow.x - blurLabel.width - blurRow.spacing - 16))
                        from: 0; to: 1; value: Global.backgroundBlur
                        onMoved: { Global.backgroundBlur = value; Global.saveSettings() }
                    }
                }
            }

            ContentBar {
                id: animationBar
                width: parent.width
                expanded: true
                title: "动画"
                contentHeight: animationSlider.y + animationSlider.height + 16
                Row {
                    x: 16; y: 48; spacing: 14
                    XCText { xcText: "当前速度"; onCenter: false; xcFontSize: 14; width: 92 }
                    XCText { xcText: Global.animationSpeed.toFixed(2) + "×"; onCenter: false; xcFontSize: 16; textColor: Colors.border }
                }
                XCSlider {
                    id: animationSlider
                    x: 16; y: 80
                    width: Math.min(360, Math.max(0, parent.width - 32))
                    from: 0.1; to: 5; stepSize: 0.05; value: Global.animationSpeed
                    onMoved: { Global.animationSpeed = value; Global.saveSettings() }
                }
            }
        }
    }
}
