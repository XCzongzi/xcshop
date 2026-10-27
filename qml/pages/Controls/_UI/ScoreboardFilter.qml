import QtQuick
import xcshop

Rectangle {
    id: root

    property bool compact: false
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

    implicitHeight: compact ? 34 : 236
    radius: 8
    color: compact ? Colors.transparent : Colors.changeA(Colors.background, 0.28)
    border.width: compact ? 0 : 1
    border.color: Colors.changeA(Colors.outline, 0.10)

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
        x: root.compact ? 0 : 10
        y: root.compact ? (parent.height - height) / 2 : 9
        width: root.compact ? 74 : implicitWidth
        xcText: "计分板筛选"
        xcFontSize: root.compact ? 12 : 13
        onCenter: false
    }

    XCText {
        visible: !root.compact
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
        x: root.compact ? 80 : 10
        y: root.compact ? 2 : 56
        width: root.compact ? Math.max(42, (parent.width - 90) / 3)
                            : parent.width - 20
        height: 30
        placeholderText: root.compact ? "计分板" : "objective"
        onEditingFinished: root.commit()
    }

    XCText {
        visible: !root.compact
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
        x: root.compact ? scoreboardInput.x + scoreboardInput.width + 5 : 10
        y: root.compact ? 2 : 112
        width: root.compact ? Math.max(42, (parent.width - 90) / 3)
                            : parent.width - 20
        height: 30
        placeholderText: root.compact ? "目标" : "@s、@p 或玩家名"
        onEditingFinished: root.commit()
    }

    XCText {
        visible: !root.compact
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
        x: root.compact ? targetInput.x + targetInput.width + 5 : 10
        y: root.compact ? 2 : 168
        width: root.compact ? Math.max(42, (parent.width - 90) / 3)
                            : parent.width - 20
        height: 30
        placeholderText: root.compact ? "分数范围" : "10、5..10、..20 或 15.."
        color: root.scoreRangeValid ? Colors.text : Colors.error
        onEditingFinished: root.commit()
    }

    XCText {
        visible: !root.compact
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
