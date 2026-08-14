pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

Window {
    id: root
    width: 800 + 2 * Constants.margins
    height: 500 + 2 * Constants.margins
    minimumWidth: 800 + 2 * Constants.margins
    minimumHeight: 500 + 2 * Constants.margins
    color: Colors.transparent
    visible: true
    title: qsTr("xcshop")


    readonly property int titleBarHeight: titleBar.height
    readonly property Image background: backgroundImage
    readonly property int titleBar_height: titleBar.height
    property string backgroundMode: Global.backgroundMode
    property color backgroundColor: Global.backgroundColor
    property string backgroundSource: Global.backgroundImage
    property real backgroundBlur: Global.backgroundBlur

    property bool titleBarColorFilling: true

    property var flowColors: {
        var palettes = {
            aurora: ["#a445d5", "#009dff", "#00d3a7"],
            ocean: ["#3157d5", "#00a8d6", "#36d1a4"],
            sunset: ["#d94d86", "#ff7a45", "#f5c451"],
            grape: ["#773fce", "#b34bd5", "#e05f9f"]
        }
        return palettes[Global.flowPalette] || palettes.aurora
    }

    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint

    Rectangle {
        id: windowSurface
        anchors.fill: parent
        anchors.margins: root.visibility === Window.Maximized ? 0 : Constants.margins
        radius: root.visibility === Window.Maximized ? 0 : Constants.window_radius
        color: root.backgroundMode === "color" ? root.backgroundColor : Colors.background_n
        border.color: Colors.shadow
        border.width: 1

        // This clips image and blur pixels to the inner window surface. The outer
        // transparent margin remains exclusively available for the drop shadow.
        Item {
            id: backgroundContent
            anchors.fill: parent
            anchors.margins: windowSurface.border.width
            clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: backgroundMask
            }

            Item {
                id: flowSource
                anchors.fill: parent
                visible: root.backgroundMode === "flow"
                clip: true
                layer.enabled: visible
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    saturation: 0.25
                    //blurMax: 128
                    //blurMultiplier: 3
                }

                Rectangle {
                    id: flowA
                    width: parent.width * 0.85
                    height: width
                    radius: width / 2
                    color: root.flowColors[0]
                    x: -width * 0.2
                    y: -height * 0.35
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        NumberAnimation { to: flowSource.width * 0.55; duration: 14000 / Math.max(0.25, Global.animationSpeed) }
                        NumberAnimation { to: -flowA.width * 0.2; duration: 14000 / Math.max(0.25, Global.animationSpeed) }
                    }
                }
                Rectangle {
                    id: flowB
                    width: parent.width * 0.75
                    height: width
                    radius: width / 2
                    color: root.flowColors[1]
                    x: parent.width * 0.5
                    y: parent.height * 0.25
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        NumberAnimation { to: -flowB.height * 0.2; duration: 12000 / Math.max(0.25, Global.animationSpeed) }
                        NumberAnimation { to: flowSource.height * 0.45; duration: 12000 / Math.max(0.25, Global.animationSpeed) }
                    }
                }
                Rectangle {
                    id: flowC
                    width: parent.width * 0.65
                    height: width
                    radius: width / 2
                    color: root.flowColors[2]
                    x: parent.width * 0.2
                    y: parent.height * 0.55
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        NumberAnimation { to: -flowC.width * 0.35; duration: 16000 / Math.max(0.25, Global.animationSpeed) }
                        NumberAnimation { to: flowSource.width * 0.65; duration: 16000 / Math.max(0.25, Global.animationSpeed) }
                    }
                }
            }

            Image {
                id: backgroundImage
                anchors.fill: parent
                source: root.backgroundSource.length ? root.backgroundSource : "qrc:/assets/gui/png/background1.png"
                visible: root.backgroundMode === "image" || root.backgroundMode === "imageBlur"
                fillMode: Image.PreserveAspectCrop
                layer.enabled: root.backgroundMode === "imageBlur"
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: root.backgroundBlur
                }
            }
        }

        // Keep the actual rounded window shape after image/blur compositing.
        Rectangle {
            id: backgroundMask
            anchors.fill: parent
            radius: windowSurface.radius
            visible: false
        }

        Behavior on color {
            ColorAnimation { duration: 500 }
        }

        layer.enabled: root.visibility !== Window.Maximized
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#d0000000"
            shadowBlur: 0.9
            shadowHorizontalOffset: 4
            shadowVerticalOffset: 4
        }
    }

    TitleBar {
        id: titleBar
        mainWindow: root
        z: 99
        onCloseClicked: Qt.quit()
        onMaximizeClicked: {
            if (root.visibility === Window.Maximized) {
                root.showFullScreen()
                root.showNormal()
            } else {
                root.showFullScreen()
                root.showMaximized()
            }
        }
        onMinimizeClicked: root.showMinimized()
        colorFilling: root.titleBarColorFilling
    }

    Border {
        id: border
        visible: root.visibility !== Window.Maximized
        mainWindow: root
        z: 100
    }
}
