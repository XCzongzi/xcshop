pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import xcshop

ContentBar {
    id: root

    property bool builderAvailable: false
    property bool building: false
    property bool canBuild: false
    property string buildState: builderAvailable ? "未构建" : "构建器不可用"
    property string buildStage: ""
    property real buildProgress: 0
    property string elapsedText: "—"
    property string outputPath: ""
    property string configuredOutputPath: ""
    property string outputFolderName: ""
    property string defaultFolderName: ""
    property bool outputSettingsEnabled: false
    readonly property alias outputFolderDraft: folderField.text
    readonly property string folderError: Global.outputFolderError(folderField.text)
    property string consoleText: ""
    property var problems: []

    signal startRequested
    signal cancelRequested
    signal outputFolderSubmitted(string name)
    signal revealRequested
    signal problemActivated(var problem)

    title: "构建"
    contentHeight: 438
    expanded: true
    padding: 20

    // 日志只保留当前构建；合并密集输出，避免每行日志都重新排版整个文本框。
    function resetConsole() {
        if (!consoleOutput)
            return
        consoleRefresh.stop()
        consoleOutput.clear()
        consoleOutput.deselect()
        consoleOutput.cursorPosition = 0
        consoleViewport.setScrollOffset(consoleViewport.originY)
    }

    function refreshConsole() {
        if (!consoleOutput)
            return
        var previous = consoleOutput.text
        var next = root.consoleText
        if (previous === next)
            return
        if (previous.length && next.indexOf(previous) === 0)
            consoleOutput.insert(consoleOutput.length, next.substring(previous.length))
        else if (previous !== next)
            consoleOutput.text = next
    }

    onBuildingChanged: {
        if (building) {
            resetConsole()
            consoleRefresh.start()
        } else {
            consoleRefresh.stop()
            refreshConsole()
        }
    }
    onConsoleTextChanged: {
        if (!consoleOutput)
            return
        if (!consoleText.length) {
            resetConsole()
        } else if (!building) {
            consoleRefresh.stop()
            refreshConsole()
        } else if (!consoleRefresh.running) {
            consoleRefresh.start()
        }
    }
    Component.onCompleted: refreshConsole()
    Timer {
        id: consoleRefresh
        interval: 80
        onTriggered: root.refreshConsole()
    }

    readonly property int errorCount: {
        var count = 0
        for (var i = 0; i < problems.length; ++i)
            if (String(problems[i].severity).toLowerCase() === "error")
                ++count
        return count
    }
    readonly property int warningCount: {
        var count = 0
        for (var i = 0; i < problems.length; ++i)
            if (String(problems[i].severity).toLowerCase() === "warning")
                ++count
        return count
    }

    Item {
        id: outputSettings
        visible: root.outputSettingsEnabled || root.configuredOutputPath.length > 0
        x: root.padding + 64
        y: 16
        width: Math.max(0, root.width - x - root.padding)
        height: 30

        XCTextField {
            id: folderField
            objectName: "buildOutputFolderField"
            anchors.right: revealButton.left
            anchors.rightMargin: 8
            width: Math.max(0, Math.min(240, parent.width - revealButton.width - 8))
            height: parent.height
            editorFontSize: 12
            text: root.outputFolderName
            placeholderText: root.defaultFolderName || "文件夹名称"
            enabled: root.outputSettingsEnabled
            selectByMouse: true
            Accessible.name: "生成文件夹名称"
            onEditingFinished: {
                if (enabled && !root.folderError.length)
                    root.outputFolderSubmitted(text)
            }
            Controls.ToolTip.visible: (activeFocus && root.folderError.length > 0) || folderHover.hovered
            Controls.ToolTip.delay: root.folderError.length ? 0 : 500
            Controls.ToolTip.text: root.folderError || "生成文件夹名称，留空使用项目名称"
            HoverHandler { id: folderHover }
        }

        ActionButton {
            id: revealButton
            objectName: "buildRevealOutputButton"
            anchors.right: parent.right
            width: 104
            height: parent.height
            text: "打开生成位置"
            textSize: 12
            enabled: root.configuredOutputPath.length > 0 && !root.building
            onClicked: root.revealRequested()
            Controls.ToolTip.visible: revealHover.hovered
            Controls.ToolTip.delay: 500
            Controls.ToolTip.text: root.configuredOutputPath
            HoverHandler { id: revealHover }
        }
    }

    Item {
        x: root.padding
        y: 54
        width: parent.width - root.padding * 2
        height: parent.height - y - 20

        Item {
            id: statusArea
            width: parent.width
            height: 68

            XCText {
                id: stateText
                width: parent.width - actionButton.width - 18
                xcText: root.buildStage.length ? root.buildState + " · " + root.buildStage : root.buildState
                onCenter: false
                xcFontSize: 14
            }
            XCText {
                y: 25
                width: parent.width - actionButton.width - 18
                xcText: "耗时 " + root.elapsedText + "   输出 "
                        + (root.outputPath.length ? root.outputPath : "—")
                onCenter: false
                xcFontSize: 11
                boldFont: false
                textColor: Colors.banned
                elide: Text.ElideMiddle
            }

            Rectangle {
                y: 51
                width: parent.width - actionButton.width - 18
                height: 5
                radius: 3
                color: Colors.changeA(Colors.outline, 0.10)

                Rectangle {
                    id: progressFill
                    width: parent.width * (root.building ? 0.28 : Math.max(0, Math.min(1, root.buildProgress)))
                    height: parent.height
                    radius: parent.radius
                    color: Colors.border
                    Behavior on width {
                        NumberAnimation { duration: 160 / Global.animationSpeed; easing.type: Easing.OutCubic }
                    }
                    SequentialAnimation on opacity {
                        running: root.building
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.35; to: 1; duration: 650 }
                        NumberAnimation { from: 1; to: 0.35; duration: 650 }
                        onRunningChanged: if (!running) progressFill.opacity = 1
                    }
                }
            }

            ActionButton {
                id: actionButton
                primary: !root.building
                destructive: root.building
                anchors.right: parent.right
                anchors.top: parent.top
                width: 104
                height: 36
                text: root.building ? "取消构建" : "开始构建"
                textSize: 12
                enabled: root.building || (root.builderAvailable && root.canBuild && !root.folderError.length)

                onClicked: {
                    if (root.building)
                        root.cancelRequested()
                    else
                        root.startRequested()
                }
            }

            XCText {
                anchors.right: parent.right
                anchors.top: actionButton.bottom
                anchors.topMargin: 5
                xcText: root.errorCount + " 错误  ·  " + root.warningCount + " 警告"
                onCenter: false
                xcFontSize: 10
                boldFont: false
                textColor: root.errorCount ? Colors.error : Colors.banned
            }
        }

        Row {
            id: outputRow
            y: statusArea.height + 14
            width: parent.width
            height: parent.height - y
            spacing: 14

            Item {
                id: consolePanel
                width: (parent.width - parent.spacing) * 0.56
                height: parent.height

                XCText {
                    xcText: "控制台"
                    onCenter: false
                    xcFontSize: 13
                }

                Flickable {
                    id: consoleViewport
                    objectName: "buildConsoleViewport"
                    y: 32
                    width: parent.width
                    height: Math.max(0, parent.height - y)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    function setScrollOffset(offset) {
                        contentY = Math.max(originY, Math.min(originY + Math.max(0, contentHeight - height), offset))
                    }
                    onContentHeightChanged: setScrollOffset(contentY)
                    onHeightChanged: setScrollOffset(contentY)

                    Controls.TextArea.flickable: XCTextArea {
                        id: consoleOutput
                        objectName: "buildConsoleOutput"
                        readOnly: true
                        selectByMouse: true
                        textFormat: TextEdit.PlainText
                        BuildConsoleDocument { document: consoleOutput.textDocument }
                        placeholderText: "暂无构建输出"
                        editorFontSize: 11
                        wrapMode: TextEdit.WrapAnywhere
                        // 固定留出滑块空间，避免显隐时反复换行、改变内容高度。
                        rightPadding: consoleScrollBar.width + 16
                    }

                    Controls.ScrollBar.vertical: XCScrollBar {
                        id: consoleScrollBar
                        objectName: "buildConsoleScrollBar"
                        x: consoleViewport.width - width - 4
                        y: 4
                        width: 8
                        height: Math.max(0, consoleViewport.height - 8)
                        hoverEnabled: true
                        visible: consoleViewport.height > 0 && consoleViewport.contentHeight > consoleViewport.height
                    }

                    WheelHandler {
                        target: null
                        onWheel: function(event) {
                            var delta = event.pixelDelta.y || event.angleDelta.y
                            if (!delta || consoleViewport.contentHeight <= consoleViewport.height) {
                                event.accepted = false
                                return
                            }
                            consoleViewport.setScrollOffset(consoleViewport.contentY - delta)
                            event.accepted = true
                        }
                    }
                }
            }

            Item {
                width: parent.width - parent.spacing - consolePanel.width
                height: parent.height

                XCText {
                    xcText: "问题"
                    onCenter: false
                    xcFontSize: 13
                }

                Rectangle {
                    y: 32
                    width: parent.width
                    height: parent.height - y
                    radius: 7
                    color: Colors.changeA(Colors.background, 0.34)

                    ListView {
                        id: problemList
                        objectName: "buildProblemsList"
                        anchors.fill: parent
                        anchors.margins: 5
                        clip: true
                        spacing: 3
                        model: root.problems

                        delegate: Rectangle {
                            id: problemRow
                            required property var model
                            readonly property var problem: model.modelData
                            width: problemList.width
                            height: 44
                            radius: 5
                            color: problemMouse.containsMouse
                                   ? Colors.changeA(Colors.fired, 0.32)
                                   : Colors.transparent

                            Rectangle {
                                x: 4
                                y: 7
                                width: 3
                                height: parent.height - 14
                                radius: 2
                                color: String(problemRow.problem.severity).toLowerCase() === "error"
                                       ? Colors.error : Colors.warning
                            }
                            XCText {
                                x: 14
                                y: 5
                                width: parent.width - 20
                                xcText: problemRow.problem.message || "未知问题"
                                onCenter: false
                                xcFontSize: 11
                                boldFont: false
                                elide: Text.ElideRight
                            }
                            XCText {
                                x: 14
                                y: 24
                                width: parent.width - 20
                                xcText: problemRow.problem.file || problemRow.problem.code || ""
                                onCenter: false
                                xcFontSize: 9
                                boldFont: false
                                textColor: Colors.banned
                                elide: Text.ElideMiddle
                            }
                            MouseArea {
                                id: problemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: problemRow.problem.file ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.problemActivated(problemRow.problem)
                            }
                            Controls.ToolTip.visible: problemMouse.containsMouse
                            Controls.ToolTip.delay: 500
                            Controls.ToolTip.text: String(problemRow.problem.reason || problemRow.problem.message || "")
                                                   + "\n" + String(problemRow.problem.file || "")
                                                   + "\n" + String(problemRow.problem.property || "")
                                                   + (problemRow.problem.solution ? "\n解决办法：" + problemRow.problem.solution : "")
                        }

                        XCText {
                            visible: root.problems.length === 0
                            anchors.centerIn: parent
                            xcText: "未发现问题"
                            xcFontSize: 12
                            boldFont: false
                            textColor: Colors.banned
                        }
                    }
                }
            }
        }
    }
}
