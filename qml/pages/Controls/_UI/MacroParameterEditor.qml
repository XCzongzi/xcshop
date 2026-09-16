pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root

    signal macrosEdited(var macros)

    implicitHeight: parameterColumn.height
    height: implicitHeight

    function setMacros(values) {
        parameterModel.clear()
        if (!Array.isArray(values))
            return
        for (var index = 0; index < values.length; ++index) {
            var parameter = values[index]
            if (!parameter || typeof parameter !== "object" || Array.isArray(parameter))
                continue
            parameterModel.append({
                "name": typeof parameter.name === "string" ? parameter.name : "",
                "value": typeof parameter.value === "string" ? parameter.value : ""
            })
        }
    }

    function exportMacros() {
        var values = []
        for (var index = 0; index < parameterModel.count; ++index) {
            var parameter = parameterModel.get(index)
            values.push({ "name": parameter.name, "value": parameter.value })
        }
        return values
    }

    function commit() {
        root.macrosEdited(exportMacros())
    }

    function updateMacro(index, name, value) {
        parameterModel.setProperty(index, "name", name)
        parameterModel.setProperty(index, "value", value)
        commit()
    }

    function removeMacro(index) {
        parameterModel.remove(index, 1)
        commit()
    }

    ListModel { id: parameterModel }

    Column {
        id: parameterColumn
        width: parent.width
        spacing: 6

        XCText {
            width: parent.width
            xcText: "宏参数"
            xcFontSize: 12
            onCenter: false
            boldFont: false
            textColor: Colors.changeA(Colors.text, 0.82)
        }

        XCText {
            width: parent.width
            xcText: "在物品内容中使用 {{名称}}；\\{{名称}} 将作为普通文本。"
            xcFontSize: 11
            onCenter: false
            boldFont: false
            textColor: Colors.banned
        }

        Repeater {
            model: parameterModel

            delegate: Row {
                id: parameterRow
                required property int index
                required property var model

                width: root.width
                height: 32
                spacing: 5

                XCTextField {
                    width: Math.max(72, (parent.width - removeButton.width - parent.spacing * 2) * 0.42)
                    height: parent.height
                    placeholderText: "参数名"
                    text: parameterRow.model.name
                    onEditingFinished: root.updateMacro(parameterRow.index, text,
                                                        parameterRow.model.value)
                }

                XCTextField {
                    width: parent.width - x - removeButton.width - parent.spacing
                    height: parent.height
                    placeholderText: "值"
                    text: parameterRow.model.value
                    onEditingFinished: root.updateMacro(parameterRow.index,
                                                        parameterRow.model.name, text)
                }

                TextButton {
                    id: removeButton
                    width: 32
                    height: parent.height
                    radius: 7
                    text: "×"
                    textSize: 18
                    boldFont: false
                    textColor: Colors.banned
                    buttonColor: Colors.changeA(Colors.text, 0.035)
                    firedColor: Colors.changeA(Colors.error, 0.18)
                    pressedColor: Colors.changeA(Colors.error, 0.28)
                    onClicked: root.removeMacro(parameterRow.index)
                }
            }
        }

        TextButton {
            width: 104
            height: 30
            radius: 7
            text: "＋ 新建参数"
            textSize: 12
            boldFont: false
            textColor: Colors.banned
            buttonColor: Colors.changeA(Colors.background, 0.38)
            firedColor: Colors.changeA(Colors.fired, 0.62)
            pressedColor: Colors.changeA(Colors.border, 0.55)
            onClicked: {
                parameterModel.append({ "name": "", "value": "" })
                root.commit()
            }
        }
    }
}
