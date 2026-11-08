pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

Item {
    id: root
    property bool compact: false
    property bool singleLine: false
    property string content: ""
    property alias input: editor
    property alias document: document
    property alias placeholderText: editor.placeholderText
    readonly property string error: document.error
    readonly property bool resizing: resizeAnimation.running
    property bool ready: false
    signal edited(string value)
    signal accepted()
    implicitHeight: compact ? (singleLine ? 34 : 128) : 450

    function setContent(value) {
        var next = value === undefined || value === null ? "" : String(value)
        if (content === next) {
            if (ready) document.load(next)
        } else content = next
    }
    function getContent() { return document.serialize() }
    function commit() { root.edited(getContent()) }
    function format(key, value) {
        document.apply(key, value)
        editor.forceActiveFocus()
    }
    onContentChanged: if (ready) document.load(content)
    Component.onCompleted: {
        ready = true
        document.load(content)
    }
    Behavior on height {
        NumberAnimation {
            id: resizeAnimation
            duration: 120 / Global.animationSpeed
            easing.type: Easing.InOutQuad
        }
    }
    RichTextDocument {
        id: document
        target: editor
        singleLine: root.singleLine
        onEdited: root.edited(document.serialize())
    }
    Rectangle {
        visible: !root.compact
        anchors.fill: parent
        radius: 9
        color: Colors.changeA(Colors.input, 0.50)
        border.width: 1
        border.color: Colors.changeA(editor.activeFocus ? Colors.border : Colors.outline,
                                     editor.activeFocus ? 0.65 : 0.12)
    }
    Item {
        id: toolbar
        objectName: "richTextToolbar"
        visible: !root.compact
        enabled: !root.error.length
        readonly property bool stacked: width < 800
        x: 10; y: 10
        width: parent.width - 20
        height: stacked ? palette.height + actions.height + 8 : Math.max(palette.height, actions.height)
        TextColorPalette {
            id: palette
            objectName: "richTextPalette"
            width: toolbar.stacked ? toolbar.width : Math.max(0, toolbar.width - actions.width - 20)
            color: document.currentStyle.color
            onColorEdited: function(value) { document.apply("color", value) }
        }
        Flow {
            id: actions
            objectName: "richTextActions"
            x: parent.width - width
            y: toolbar.stacked ? palette.height + 8 : 0
            width: Math.min(toolbar.width, styleActions.implicitWidth + historyActions.implicitWidth + 8)
            layoutDirection: Qt.RightToLeft
            spacing: 8
            Row {
                id: historyActions
                spacing: 4
                TextButton {
                    id: undoButton
                    text: "撤销"; height: 26; radius: 5; widthBorderSize: 7
                    boldFont: false; textSize: 11; enabled: editor.canUndo
                    onClicked: { editor.undo(); editor.forceActiveFocus() }
                    XCToolTip { active: undoButton.hovered; text: "撤销 · Ctrl+Z" }
                }
                TextButton {
                    id: redoButton
                    text: "重做"; height: 26; radius: 5; widthBorderSize: 7
                    boldFont: false; textSize: 11; enabled: editor.canRedo
                    onClicked: { editor.redo(); editor.forceActiveFocus() }
                    XCToolTip { active: redoButton.hovered; text: "重做 · Ctrl+Shift+Z" }
                }
            }
            Row {
                id: styleActions
                spacing: 4
                Repeater {
                    model: [
                        {key: "bold", label: "粗", tip: "粗体 · Ctrl+B"},
                        {key: "italic", label: "斜", tip: "斜体 · Ctrl+I"},
                        {key: "underlined", label: "下", tip: "下划线 · Ctrl+U"},
                        {key: "strikethrough", label: "删", tip: "删除线"},
                        {key: "obfuscated", label: "乱", tip: "混淆 · 游戏中显示为随机字符"}
                    ]
                    delegate: BooleanSwitch {
                        id: toggle
                        required property var modelData
                        objectName: "richTextStyle_" + modelData.key
                        width: 26; height: 26
                        label: modelData.label
                        checked: !!document.currentStyle[modelData.key]
                        onToggled: function(value) { root.format(toggle.modelData.key, value) }
                        XCToolTip { active: toggle.hovered; text: toggle.modelData.tip }
                    }
                }
                TextButton {
                    objectName: "richTextResetStyle"
                    text: "清除格式"
                    height: 26; radius: 5; widthBorderSize: 7
                    boldFont: false; textSize: 11
                    onClicked: { document.resetStyle(); editor.forceActiveFocus() }
                }
            }
        }
    }
    Item {
        id: editingFrame
        objectName: "richTextEditingFrame"
        x: root.compact ? 0 : 1
        y: root.compact ? 0 : toolbar.y + toolbar.height + 12
        width: parent.width - x * 2
        height: Math.max(0, parent.height - y - (root.compact ? (root.singleLine ? 0 : 35) : 1)
                         - (root.error.length ? errorLabel.height + 8 : 0))
        InputBackground {
            anchors.fill: parent
            focused: editor.activeFocus
            idleOpacity: 0.50
            color: root.compact
                   ? Colors.changeA(Colors.isLight ? Qt.tint(Colors.input, "#33ffffff") : Colors.input,
                                    focused ? 0.72 : idleOpacity)
                   : Colors.isLight ? "#24262e" : Colors.changeA(Colors.input, focused ? 0.72 : idleOpacity)
        }
        Flickable {
            id: viewport
            objectName: "richTextViewport"
            anchors.fill: parent
            anchors.rightMargin: root.singleLine ? 0 : 14
            contentWidth: width
            contentHeight: editor.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: XCScrollBar {
                id: scrollBar
                objectName: "richTextScrollBar"
                visible: !root.singleLine
                parent: editingFrame
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                width: 8
            }
            Controls.TextArea.flickable: Controls.TextArea {
                id: editor
                objectName: "richTextInput"
                width: viewport.width
                height: Math.max(viewport.height, implicitHeight)
                textFormat: TextEdit.RichText
                wrapMode: root.singleLine ? TextEdit.NoWrap : TextEdit.WrapAnywhere
                selectByMouse: true
                persistentSelection: true
                readOnly: root.error.length > 0
                color: "#ffffff"
                placeholderTextColor: Colors.changeA(Colors.placeholder, 0.78)
                selectionColor: Colors.selection
                selectedTextColor: Colors.selectionContent
                leftPadding: root.compact ? 10 : 14
                rightPadding: 10
                topPadding: root.compact && root.singleLine ? 0 : 8
                bottomPadding: topPadding
                verticalAlignment: root.compact && root.singleLine ? TextEdit.AlignVCenter : TextEdit.AlignTop
                font: EditorFonts.mixedFont(Global.editorChineseFont, Global.editorLatinFont, root.compact ? 16 : 19)
                background: Item {}
                Keys.onPressed: function(event) {
                    if (root.singleLine && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        if (event.modifiers & Qt.ControlModifier) {
                            root.commit(); root.accepted()
                        }
                        event.accepted = true
                        return
                    }
                    if (!(event.modifiers & Qt.ControlModifier)) return
                    var key = event.key === Qt.Key_B ? "bold" : event.key === Qt.Key_I ? "italic"
                              : event.key === Qt.Key_U ? "underlined" : ""
                    if ((!root.compact || root.singleLine) && key.length) {
                        root.format(key, !document.currentStyle[key]); event.accepted = true
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.commit(); root.accepted(); event.accepted = true
                    }
                }
            }
        }
    }
    XCText {
        id: errorLabel
        x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: root.compact ? 38 : 8
        width: parent.width - 20
        visible: root.error.length > 0
        xcText: root.error; xcFontSize: 11; boldFont: false
        textColor: Colors.error; onCenter: false; xcWrapMode: true
    }
    Row {
        visible: root.compact && !root.singleLine
        x: parent.width - width
        y: root.height - 32
        ImageButton {
            objectName: "richTextCollapse"
            btnSize: 32; imgSize: 24; btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_up.png"
            onClicked: root.height = Math.max(128, root.height - 128)
        }
        ImageButton {
            objectName: "richTextExpand"
            btnSize: 32; imgSize: 24; btnRadius: 3
            imageSource: "qrc:/assets/gui/controls/expand_down.png"
            onClicked: root.height += 128
        }
    }
}
