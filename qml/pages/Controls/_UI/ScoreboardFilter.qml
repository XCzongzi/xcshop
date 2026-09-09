import QtQuick
import xcshop

Rectangle {
    id: root

    property alias scoreboardName: scoreboardInput.text
    property alias targetName: targetInput.text
    property alias scoreRange: scoreInput.text
    readonly property bool scoreRangeValid: {
        var value = scoreRange.trim()
        if (!value.length)
            return true
        if (/^-?\d+$/.test(value))
            return true
        var range = value.match(/^(-?\d*)\.\.(-?\d*)$/)
        return range !== null && (range[1].length > 0 || range[2].length > 0)
    }

    signal filterEdited(string scoreboardName, string targetName, string scoreRange)

    implicitHeight: 236
    radius: 8
    color: Colors.changeA(Colors.background, 0.28)
    border.width: 1
    border.color: Colors.changeA(Colors.text, 0.10)

    function setValues(scoreboardName, targetName, scoreRange) {
        scoreboardInput.text = scoreboardName || ""
        targetInput.text = targetName || ""
        scoreInput.text = scoreRange || ""
    }

    function commit() {
        filterEdited(scoreboardInput.text.trim(), targetInput.text.trim(),
                     scoreInput.text.trim())
    }

    XCText {
        x: 10
        y: 9
        xcText: "计分板筛选"
        xcFontSize: 13
        onCenter: false
    }

    XCText {
        x: 10
        y: 38
        width: parent.width - 20
        xcText: "计分板名"
        xcFontSize: 11
        boldFont: false
        onCenter: false
        textColor: Colors.changeA(Colors.text, 0.78)
    }

    XCTextField {
        id: scoreboardInput
        x: 10
        y: 56
        width: parent.width - 20
        height: 30
        placeholderText: "objective"
        onEditingFinished: root.commit()
    }

    XCText {
        x: 10
        y: 94
        width: parent.width - 20
        xcText: "目标名"
        xcFontSize: 11
        boldFont: false
        onCenter: false
        textColor: Colors.changeA(Colors.text, 0.78)
    }

    XCTextField {
        id: targetInput
        x: 10
        y: 112
        width: parent.width - 20
        height: 30
        placeholderText: "@s、@p 或玩家名"
        onEditingFinished: root.commit()
    }

    XCText {
        x: 10
        y: 150
        width: parent.width - 20
        xcText: "分数"
        xcFontSize: 11
        boldFont: false
        onCenter: false
        textColor: Colors.changeA(Colors.text, 0.78)
    }

    XCTextField {
        id: scoreInput
        x: 10
        y: 168
        width: parent.width - 20
        height: 30
        placeholderText: "10、5..10、..20 或 15.."
        color: root.scoreRangeValid ? Colors.text : Colors.error
        onEditingFinished: root.commit()
    }

    XCText {
        x: 10
        y: 203
        width: parent.width - 20
        xcText: root.scoreRangeValid
                ? "留空表示不使用此筛选"
                : "请输入整数或 Minecraft 分数区间"
        xcFontSize: 10
        boldFont: false
        onCenter: false
        textColor: root.scoreRangeValid ? Colors.banned : Colors.error
    }
}
