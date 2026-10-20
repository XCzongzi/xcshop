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
    readonly property int titleBar_height: titleBar.height
    property string backgroundMode: Global.backgroundMode
    property color backgroundColor: Colors.backgroundColor
    property string backgroundSource: Global.backgroundImage
    property real backgroundBlur: Global.backgroundBlur

    property bool titleBarColorFilling: false
    property int margins: visibility === Window.Maximized? 0 : Constants.margins
    readonly property int surfaceWidth: windowSurface.width
    readonly property int surfaceHeight: windowSurface.height
    
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint

    // Keep flags stable so minimizing never destroys the previous normal or
    // maximized placement. NativeFramelessWindow backports QTBUG-127116.

    Rectangle {
        id: windowSurface
        
        x: root.margins
        y: root.margins
        width: root.width - 2*root.margins
        height: root.height - 2*root.margins
        radius: Constants.window_radius
        color: Colors.background_n

        Behavior on color {
            ColorAnimation { duration: 500 / Global.animationSpeed }
        }

        Item{
            anchors.fill: parent
            Image {
                id: backgroundImage
                anchors.fill: parent
                source: root.backgroundSource.length ? root.backgroundSource : "qrc:/assets/gui/png/background1.png"
                visible: root.backgroundMode === "image"
                fillMode: Image.PreserveAspectCrop
                layer.enabled: root.backgroundBlur > 0
                layer.effect: MultiEffect {
                    blurEnabled: root.backgroundBlur > 0
                    blur: root.backgroundBlur
                }
            }
            

            layer.enabled: root.visibility !== Window.Maximized
            layer.effect: OpacityMask{
                maskSource: Rectangle{
                    width: root.surfaceWidth
                    height: root.surfaceHeight
                    radius: Constants.window_radius
                }
            }
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
        onCloseClicked: root.close()
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
