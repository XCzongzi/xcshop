pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    property var accentChoices: Colors.accentChoices
    readonly property var colorChoices: Colors.colorSchemes

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

    SettingsSection {
        title: "界面"
        anchors.fill: parent

        SettingsCard {
            id: themeBar
            width: parent.width
            title: "主题与配色"
            contentHeight: schemeGrid.height
            Column {
                id: schemeGrid
                width: parent.width
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
                                id: accentChoice
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
                                    border.color: parent.selected ? Colors.changeA(Colors.background, 0.88) : Colors.changeA(Colors.outline, 0.32)
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
                            xcText: schemeRow.modelData; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned
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
                                    id: paletteChoice
                                    required property int index
                                property var schemeChoice: root.colorChoices[index * 2 + schemeRow.schemeRowIndex]
                                    objectName: "themePreview_" + schemeChoice.id
                                    property bool selected: Colors.colorScheme === schemeChoice.id
                                    property bool hovered: false
                                    property bool pressed: false
                                    width: schemeGrid.cardWidth; height: 76
                                    Rectangle {
                                        objectName: "themePreviewSurface_" + paletteChoice.schemeChoice.id
                                        anchors.centerIn: parent; width: parent.width; height: parent.height; radius: 8
                                        color: paletteChoice.schemeChoice.background
                                        border.width: parent.selected ? 2 : 1; border.color: parent.selected ? Colors.themeColor : Qt.rgba(0, 0, 0, 0.18)
                                        scale: parent.pressed ? 0.975 : (parent.hovered && !parent.selected ? 1.025 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 120 / Global.animationSpeed } }
                                        Rectangle { x: 8; y: 8; width: parent.width - 16; height: 16; radius: 4; color: paletteChoice.schemeChoice.foreground }
                                        Rectangle { x: 12; y: 12; width: 34; height: 3; radius: 2; color: paletteChoice.schemeChoice.text }
                                            XCText { x: 52; y: 8; width: 66; height: 16; xcText: paletteChoice.schemeChoice.name; onCenter: false; xcFontSize: 11; boldFont: false; textColor: paletteChoice.schemeChoice.text }
                                            Rectangle { x: 8; y: 31; width: 66; height: 34; radius: 5; color: paletteChoice.schemeChoice.foreground }
                                            Rectangle { x: 13; y: 38; width: 42; height: 6; radius: 3; color: paletteChoice.schemeChoice.background }
                                            Rectangle { x: 82; y: 31; width: 38; height: 16; radius: 5; color: paletteChoice.schemeChoice.surface }
                                            Rectangle { x: 82; y: 53; width: 38; height: 12; radius: 4; color: paletteChoice.schemeChoice.foreground }
                                            Rectangle { x: 104; y: 35; width: 12; height: 8; radius: 4; color: root.accentForColorScheme(paletteChoice.schemeChoice.id) || Colors.themeColor }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: parent.hovered = true
                                            onExited: { parent.hovered = false; parent.pressed = false }
                                            onPressed: parent.pressed = true
                                            onReleased: parent.pressed = false
                                            onClicked: root.chooseColorScheme(paletteChoice.schemeChoice.id)
                                        }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

        SettingsCard {
            id: backgroundBar
            width: parent.width
            title: "背景"
            contentHeight: blurRow.visible ? blurRow.y + blurRow.height : backgroundType.y + backgroundType.height

            RadioGroup {
                id: backgroundType
                x: 0
                y: 0
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
                x: 0
                y: backgroundType.y + backgroundType.height + 12
                visible: Global.backgroundMode === "image"
                spacing: 10
                ActionButton { text: "选择图片"
                    onClicked: imageFileDialog.openXC(false, "background") }
                    XCText { width: Math.max(120, parent.parent.width - 144); xcText: Global.backgroundImage.length ? Global.backgroundImage : "未选择图片"; onCenter: false; xcFontSize: 12; boldFont: false; textColor: Colors.banned; elide: Text.ElideMiddle }
                }
                Row {
                    id: blurRow
                    x: 0
                y: imageRow.y + imageRow.height + 10
                visible: imageRow.visible
                spacing: 10
                XCText { id: blurLabel; xcText: "模糊强度"; onCenter: false; xcFontSize: 13; boldFont: false; width: 70 }
                XCSlider {
                    width: Math.min(260, Math.max(0, parent.parent.width - blurLabel.width - blurRow.spacing))
                    from: 0; to: 1; value: Global.backgroundBlur
                    onMoved: { Global.backgroundBlur = value; Global.saveSettings() }
                }
            }
        }

        SettingsCard {
            id: animationBar
            width: parent.width
            title: "动画"
            contentHeight: animationSlider.y + animationSlider.height
            Row {
                y: 0
                spacing: 14
                XCText { xcText: "当前速度"; onCenter: false; xcFontSize: 14; width: 92 }
                XCText { xcText: Global.animationSpeed.toFixed(2) + "×"; onCenter: false; xcFontSize: 16; textColor: Colors.accentText }
            }
            XCSlider {
                id: animationSlider
                y: 32
                width: Math.min(360, Math.max(0, parent.width))
                from: 0.1; to: 5; stepSize: 0.05; value: Global.animationSpeed
                onMoved: { Global.animationSpeed = value; Global.saveSettings() }
            }
        }
    }
}
