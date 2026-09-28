pragma ComponentBehavior: Bound
import QtQuick
import xcshop

ContentBar {
    id: root

    property bool builderAvailable: false
    property bool building: false
    property bool canBuild: false
    property string buildState: builderAvailable ? "未构建" : "构建器未接入"
    property string buildStage: ""
    property real buildProgress: 0
    property string elapsedText: "—"
    property string outputPath: ""
    property string consoleText: ""
    property var problems: []

    signal startRequested()
    signal cancelRequested()
    signal problemActivated(var problem)

    title: "构建"
    subtitle: root.buildState
    contentHeight: 438
    expanded: true

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
        x: 16
        y: 62
        width: parent.width - 32
        height: parent.height - y - 8

        Item {
            id: statusArea
            width: parent.width
            height: 57

            XCText {
                id: stateText
                width: parent.width - actionButton.width - 18
                xcText: root.buildStage.length ? root.buildState + " · " + root.buildStage : root.buildState
                onCenter: false
                xcFontSize: 14
            }
            XCText {
                y: 21
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
                y: 44
                width: parent.width - actionButton.width - 18
                height: 5
                radius: 3
                color: Colors.changeA(Colors.text, 0.10)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.buildProgress))
                    height: parent.height
                    radius: parent.radius
                    color: Colors.border
                    Behavior on width {
                        NumberAnimation { duration: 160 / Global.animationSpeed; easing.type: Easing.OutCubic }
                    }
                }
            }

            TextButton {
                id: actionButton
                anchors.right: parent.right
                anchors.top: parent.top
                width: 104
                height: 36
                radius: 7
                text: root.building ? "取消构建" : "开始构建"
                textSize: 12
                enabled: root.building || (root.builderAvailable && root.canBuild)
                buttonColor: root.building
                             ? Colors.changeA(Colors.error, 0.18)
                             : Colors.changeA(Colors.border, 0.72)
                firedColor: root.building
                            ? Colors.changeA(Colors.error, 0.28)
                            : Colors.changeA(Colors.border, 0.90)
                pressedColor: root.building ? Colors.changeA(Colors.error, 0.38) : Colors.border
                textColor: root.building ? Colors.text : "#1b1b1b"
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
            y: statusArea.height + 4
            width: parent.width
            height: parent.height - y
            spacing: 10

            Item {
                id: consolePanel
                width: (parent.width - parent.spacing) * 0.56
                height: parent.height

                XCText {
                    xcText: "控制台"
                    onCenter: false
                    xcFontSize: 13
                }

                XCTextArea {
                    id: consoleOutput
                    y: 26
                    width: parent.width
                    height: parent.height - y
                    readOnly: true
                    selectByMouse: true
                    text: root.consoleText
                    placeholderText: "暂无构建输出"
                    font.pixelSize: 11
                    font.family: "Consolas"
                    wrapMode: TextEdit.WrapAnywhere
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
                    y: 26
                    width: parent.width
                    height: parent.height - y
                    radius: 7
                    color: Colors.changeA(Colors.background, 0.34)

                    ListView {
                        id: problemList
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
                                       ? Colors.error : "#e0a33b"
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
