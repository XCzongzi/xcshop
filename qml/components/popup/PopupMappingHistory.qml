pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Item {
    id: root
    anchors.fill: parent

    // 由 SettingsItems 注入；保留对象引用可使异步加载的版本列表自动更新。
    property var settingsPage: null
    signal closed(int result)

    function open() {
        if (settingsPage)
            settingsPage.loadHistoricalMappingVersions()
    }

    function close(result) {
        closed(result === undefined ? 0 : result)
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.46

        MouseArea {
            anchors.fill: parent
            onClicked: root.close(0)
        }
    }

    Rectangle {
        id: panel
        width: Math.min(440, Math.max(300, parent.width - 48))
        height: 330
        anchors.centerIn: parent
        radius: 14
        color: Colors.changeA(Colors.background, 0.985)
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.12)

        layer.enabled: true
        layer.effect: XCShadow {
            shadowColor: "#a8000000"
            shadowBlur: 0.85
            shadowVerticalOffset: 10
            shadowHorizontalOffset: 0
        }

        MouseArea { anchors.fill: parent }

        Rectangle {
            width: parent.width
            height: 5
            radius: parent.radius
            color: Colors.border
        }

        XCText {
            x: 22
            y: 22
            width: parent.width - 44
            xcText: "选择历史映射表版本"
            onCenter: false
            xcFontSize: 19
        }

        XCText {
            x: 22
            y: 53
            width: parent.width - 44
            xcText: root.settingsPage ? root.settingsPage.historicalVersionsStatus : ""
            onCenter: false
            xcFontSize: 12
            boldFont: false
            textColor: xcText.indexOf("无法") >= 0 || xcText.indexOf("无效") >= 0
                       ? Colors.error : Colors.banned
        }

        Rectangle {
            x: 22
            y: 78
            width: parent.width - 44
            height: 1
            color: Colors.changeA(Colors.text, 0.10)
        }

        ListView {
            id: historicalVersionList
            x: 22
            y: 90
            width: parent.width - 44
            height: 180
            clip: true
            spacing: 3
            model: root.settingsPage ? root.settingsPage.historicalMappingVersions : []

            delegate: TextButton {
                required property var modelData
                width: historicalVersionList.width - (historicalVersionScrollBar.visible ? 10 : 0)
                height: 32
                radius: 7
                text: modelData
                textSize: 13
                boldFont: false
                widthBorderSize: 10
                buttonColor: Colors.changeA(Colors.foreground, 0.74)
                firedColor: Colors.changeA(Colors.border, 0.76)
                onClicked: {
                    if (root.settingsPage)
                        root.settingsPage.downloadMappings(modelData)
                    root.close(1)
                }
            }

            XCText {
                anchors.centerIn: parent
                visible: root.settingsPage && root.settingsPage.historicalVersionsLoading
                xcText: "正在读取版本…"
                xcFontSize: 13
                boldFont: false
                textColor: Colors.banned
            }
        }

        Rectangle {
            id: historicalVersionScrollBar
            anchors.top: historicalVersionList.top
            anchors.bottom: historicalVersionList.bottom
            anchors.right: historicalVersionList.right
            width: 6
            radius: width / 2
            visible: historicalVersionList.contentHeight > historicalVersionList.height
            color: Colors.changeA(Colors.background, 0.30)

            readonly property real maxContentY: Math.max(0, historicalVersionList.contentHeight - historicalVersionList.height)
            readonly property real maxThumbY: Math.max(0, height - historicalVersionScrollThumb.height)

            Rectangle {
                id: historicalVersionScrollThumb
                width: parent.width
                height: Math.max(28, parent.height * historicalVersionList.height
                                 / Math.max(historicalVersionList.height, historicalVersionList.contentHeight))
                y: historicalVersionScrollBar.maxContentY > 0
                   ? historicalVersionList.contentY / historicalVersionScrollBar.maxContentY
                     * historicalVersionScrollBar.maxThumbY : 0
                radius: width / 2
                color: historicalVersionScrollHandle.containsMouse || historicalVersionScrollHandle.pressed
                       ? Colors.changeA(Colors.border, 0.92)
                       : Colors.changeA(Colors.banned, 0.62)

                MouseArea {
                    id: historicalVersionScrollHandle
                    anchors.fill: parent
                    hoverEnabled: true
                    property real previousY: 0
                    onPressed: previousY = mouseY
                    onPositionChanged: {
                        if (!pressed || historicalVersionScrollBar.maxThumbY <= 0)
                            return
                        var targetY = Math.max(0, Math.min(historicalVersionScrollBar.maxThumbY,
                                                           historicalVersionScrollThumb.y + mouseY - previousY))
                        historicalVersionList.contentY = targetY / historicalVersionScrollBar.maxThumbY
                                                         * historicalVersionScrollBar.maxContentY
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: function(mouse) {
                    if (historicalVersionScrollBar.maxThumbY <= 0)
                        return
                    var targetY = Math.max(0, Math.min(historicalVersionScrollBar.maxThumbY,
                                                       mouse.y - historicalVersionScrollThumb.height / 2))
                    historicalVersionList.contentY = targetY / historicalVersionScrollBar.maxThumbY
                                                     * historicalVersionScrollBar.maxContentY
                }
            }
        }

        TextButton {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: "关闭"
            height: 34
            radius: 7
            textSize: 13
            widthBorderSize: 12
            buttonColor: Colors.pressed
            onClicked: root.close(0)
        }
    }
}
