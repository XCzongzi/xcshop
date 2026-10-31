pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import xcshop

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
    readonly property Item backdrop: rawBackdrop
    property string backgroundMode: Global.backgroundMode
    property color backgroundColor: Colors.backgroundColor
    property string backgroundSource: Global.backgroundImage
    property real backgroundBlur: Global.backgroundBlur

    property bool titleBarColorFilling: false
    readonly property bool expanded: windowState.maximized || windowState.fullScreen
    readonly property real margins: Constants.margins * (1 - windowState.frameProgress)
    readonly property real frameRadius: Constants.window_radius * (1 - windowState.frameProgress)
    readonly property bool roundedFrame: margins > 0.01
    readonly property real titleButtonSize: 30 + 6 * windowState.frameProgress
    readonly property int surfaceWidth: windowSurface.width
    readonly property int surfaceHeight: windowSurface.height
    readonly property bool windowTransitionRunning: windowState.transitioning
    
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint

    WindowStateController {
        id: windowState
        window: root
    }

    function finishWindowTransition() {
        windowState.finishTransition()
    }

    function minimize() {
        finishWindowTransition()
        windowState.minimize()
    }

    function toggleMaximized() {
        windowState.toggleMaximized(Math.max(60, 160 / Global.animationSpeed))
    }

    Item {
        id: windowSurface
        
        x: root.margins
        y: root.margins
        width: root.width - 2*root.margins
        height: root.height - 2*root.margins
        // Keep hover captures separate from the rounded, shadowed display
        // layer so a cropped capture cannot alter the window's own texture.
        Rectangle {
            id: rawBackdrop
            anchors.fill: parent
            color: Colors.background_n

            Behavior on color {
                ColorAnimation { duration: 500 / Global.animationSpeed }
            }

            Image {
                id: backgroundImage
                anchors.fill: parent
                source: root.backgroundSource.length ? root.backgroundSource : "qrc:/assets/backgrounds/望夜城.png"
                visible: root.backgroundMode === "image"
                fillMode: Image.PreserveAspectCrop
                layer.enabled: root.backgroundBlur > 0
                layer.effect: MultiEffect {
                    blurEnabled: root.backgroundBlur > 0
                    blur: root.backgroundBlur
                }
            }
        }

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: rawBackdrop
            // Keep nested image effects visible to the renderer while hiding
            // the original backdrop from the normal scene composition.
            hideSource: true
            live: true
            layer.enabled: root.roundedFrame
            layer.effect: OpacityMask{
                maskSource: Rectangle{
                    width: root.surfaceWidth
                    height: root.surfaceHeight
                    radius: root.frameRadius
                }
            }
        }
        layer.enabled: root.roundedFrame
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
        onCloseClicked: root.close()
        onMaximizeClicked: root.toggleMaximized()
        onMinimizeClicked: root.minimize()
        colorFilling: root.titleBarColorFilling
    }

    Border {
        id: border
        mainWindow: root
        z: 100
    } 
}
