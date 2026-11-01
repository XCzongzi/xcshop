pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    property bool updatingModel: false

    signal macrosEdited(var macros)

    implicitHeight: parameterColumn.height
    height: implicitHeight

    function setMacros(values) {
        var parameters = []
        var source = Array.isArray(values) ? values : []
        for (var index = 0; index < source.length; ++index) {
            var parameter = source[index]
            if (!parameter || typeof parameter !== "object" || Array.isArray(parameter))
                continue
            parameters.push({
                "name": typeof parameter.name === "string" ? parameter.name : "",
                "value": typeof parameter.value === "string" ? parameter.value : ""
            })
        }
        // Saving another field refreshes this editor too. Reuse its rows so
        // the input receiving the click keeps its focus and unfinished text.
        root.updatingModel = true
        try {
            for (var row = 0; row < parameters.length; ++row) {
                var next = parameters[row]
                if (row >= parameterModel.count) {
                    parameterModel.append(next)
                    continue
                }
                var current = parameterModel.get(row)
                if (current.name !== next.name)
                    parameterModel.setProperty(row, "name", next.name)
                if (current.value !== next.value)
                    parameterModel.setProperty(row, "value", next.value)
            }
            if (parameterModel.count > parameters.length)
                parameterModel.remove(parameters.length, parameterModel.count - parameters.length)
        } finally {
            root.updatingModel = false
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
        if (root.updatingModel || index < 0 || index >= parameterModel.count)
            return
        var current = parameterModel.get(index)
        if (current.name === name && current.value === value)
            return
        parameterModel.setProperty(index, "name", name)
        parameterModel.setProperty(index, "value", value)
        commit()
    }

    function removeMacro(index) {
        if (index < 0 || index >= parameterModel.count)
            return
        root.updatingModel = true
        try {
            parameterModel.remove(index, 1)
        } finally {
            root.updatingModel = false
        }
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
                    text: ""
                    ThemedIcon {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        iconSource: "qrc:/assets/gui/controls/delete.svg"
                        tintColor: Colors.banned
                    }
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
