pragma ComponentBehavior: Bound
import QtQuick
import xcshop

SettingsCard {
    id: root
    objectName: "editorFontSettings"
    title: "编辑框字体"
    contentHeight: fontForm.height
    property string feedback: ""

    function fontOptions(families, current, defaultFamily, defaultLabel) {
        var result = []
        var available = families.indexOf(current) >= 0
        if (!available)
            result.push({ label: current + "（未安装，将使用系统替代字体）", value: current })
        for (var i = 0; i < families.length; ++i) {
            var family = families[i]
            result.push({ label: family === defaultFamily ? defaultLabel + "（默认）" : family, value: family })
        }
        return result
    }

    function saveFonts(chinese, latin) {
        Global.editorChineseFont = chinese
        Global.editorLatinFont = latin
        feedback = Global.saveSettings() ? "字体设置已保存，已应用到所有编辑框。"
                                         : "字体已应用，但保存失败，请检查设置文件的写入权限。"
    }

    Column {
        id: fontForm
        width: parent.width
        spacing: 12

        XCText { xcText: "常规字体"; onCenter: false; xcFontSize: 13; boldFont: false }
        XCComboBox {
            objectName: "editorChineseFontPicker"
            width: parent.width
            value: Global.editorChineseFont
            options: root.fontOptions(EditorFonts.chineseFamilies, value, "Microsoft YaHei", "微软雅黑 / Microsoft YaHei")
            onValueActivated: function(value) { root.saveFonts(value, Global.editorLatinFont) }
        }
        XCText { xcText: "半角字符字体"; onCenter: false; xcFontSize: 13; boldFont: false }
        XCComboBox {
            objectName: "editorLatinFontPicker"
            width: parent.width
            value: Global.editorLatinFont
            options: root.fontOptions(EditorFonts.latinFamilies, value, "Consolas", "Consolas")
            onValueActivated: function(value) { root.saveFonts(Global.editorChineseFont, value) }
        }
        Flow {
            width: parent.width
            spacing: 8
            SettingsActionButton {
                objectName: "resetEditorFonts"
                text: "恢复默认字体"
                onClicked: root.saveFonts("Microsoft YaHei", "Consolas")
            }
        }
        XCText {
            width: parent.width; onCenter: false; xcWrapMode: true; xcFontSize: 12; boldFont: false
            visible: root.feedback.length > 0
            xcText: root.feedback
            textColor: Colors.banned
        }
    }
}
