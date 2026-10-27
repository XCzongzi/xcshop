pragma ComponentBehavior: Bound
import QtQuick
import xcshop

ContentBar {
    id: root

    property var projectData: ({})
    property string projectLocation: ""
    property var templateOptions: []

    signal editRequested
    signal revealRequested(string path)

    title: "当前项目"
    subtitle: root.projectLocation
    contentHeight: 230
    expanded: true
    padding: 20

    function fieldValue(key, fallback) {
        if (!projectData || projectData[key] === undefined || projectData[key] === null)
            return fallback
        var value = String(projectData[key])
        return value.length ? value : fallback
    }

    function templateLabel(value) {
        for (var i = 0; i < templateOptions.length; ++i) {
            if (String(templateOptions[i].value).toLowerCase() === String(value).toLowerCase())
                return String(templateOptions[i].label)
        }
        return value === undefined || value === null || String(value).length === 0
                ? "未设置 / 旧模板" : "未安装的模板"
    }

    Item {
        x: root.padding
        y: 76
        width: parent.width - root.padding * 2
        height: parent.height - y - 20

        Grid {
            id: summaryGrid
            width: parent.width
            columns: 5
            columnSpacing: 12
            rowSpacing: 6

            SummaryField {
                label: "项目名称"
                value: root.fieldValue("name", "未设置")
            }

            SummaryField {
                label: "命名空间"
                value: root.fieldValue("namespace", "未设置")
            }

            SummaryField {
                label: "构建模板"
                value: root.templateLabel(root.projectData ? root.projectData.templateId : "")
            }

            SummaryField {
                label: "目标版本"
                value: root.fieldValue("version", "未设置")
            }

            SummaryField {
                label: "数据格式"
                value: root.fieldValue("dataVersion", "未设置")
            }
        }

        XCText {
            id: outputLabel
            y: summaryGrid.height + 12
            xcText: "数据包生成父目录"
            xcFontSize: 10
            boldFont: false
            onCenter: false
            textColor: Colors.changeA(Colors.text, 0.62)
        }

        XCText {
            y: outputLabel.y + 17
            anchors.left: parent.left
            anchors.right: actionRow.left
            anchors.rightMargin: 12
            xcText: root.fieldValue("generatePath", "未设置")
            xcFontSize: 12
            boldFont: false
            onCenter: false
            elide: Text.ElideMiddle
            textColor: xcText === "未设置" ? Colors.banned : Colors.text
        }

        Row {
            id: actionRow
            anchors.right: parent.right
            y: outputLabel.y + 10
            height: 29
            spacing: 6

            TextButton {
                text: "打开目录"
                height: parent.height
                radius: 6
                textSize: 10
                widthBorderSize: 8
                buttonColor: Colors.changeA(Colors.pressed, 0.72)
                onClicked: root.revealRequested(root.projectLocation)
            }

            ActionButton {
                primary: true

                text: "项目设置"
                height: parent.height
                radius: 6
                textSize: 10
                widthBorderSize: 9

                onClicked: root.editRequested()
            }
        }
    }

    component SummaryField: Item {
        property alias label: labelText.xcText
        property alias value: valueText.xcText
        width: (summaryGrid.width - summaryGrid.columnSpacing * (summaryGrid.columns - 1)) / summaryGrid.columns
        height: 39

        XCText {
            id: labelText
            width: parent.width
            xcFontSize: 10
            boldFont: false
            onCenter: false
            textColor: Colors.changeA(Colors.text, 0.62)
        }

        XCText {
            id: valueText
            y: 16
            width: parent.width
            xcFontSize: 12
            boldFont: false
            onCenter: false
            elide: Text.ElideRight
            textColor: valueText.xcText === "未设置" ? Colors.banned : Colors.text
        }
    }
}
