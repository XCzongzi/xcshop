import QtQuick
import xcshop


Item{
    id: root
    width: 210 * scale
    height: 140 * scale
    property string title
    property string subtitle
    property string icon

    signal clicked()

    //自适应
    property int layout_height: parent.height
    property int layout_width
    property int layout_amount: 1
    property real minimumScale: 1.0

    property double scale: Math.max(Math.min(layout_width/layout_amount/300 , layout_height/200), minimumScale)


    Rectangle{
        id: buttonSurface
        radius: 8 * root.scale
        color: Colors.card
        width: root.width;height: root.height

        border.width: 1
        border.color: Colors.glass_highlight

        layer.enabled: true
        layer.effect: XCShadow{shadowVerticalOffset: 3 - y}
        Behavior on y{
            NumberAnimation{
                duration: 50 / Global.animationSpeed
            }
        }
        property bool hovered: false
        property bool pressed: false
        ButtonStateOverlay {
            hoverColor: Colors.fired
            pressedColor: Colors.pressed
            hovered: buttonSurface.hovered
            pressed: buttonSurface.pressed
            stateEnabled: buttonSurface.enabled
            duration: 120
            cornerRadius: buttonSurface.radius
        }
        MouseArea {
            id:mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked:root.clicked()
            onEntered:{
                parent.y = -8
                parent.hovered = true
            }
            onExited:{
                parent.y = 0
                parent.hovered = false
                parent.pressed = false
            }
            onPressed: { parent.pressed = true; forceActiveFocus() }
            onReleased: parent.pressed = false
        }

        //光效果纹理
        LightEffect{
            lightSource_x: mouseArea.mouseX
            lightSource_r: 50 * root.scale
            blur:2*root.scale
            lightColor: Colors.ambientAccent
        }

        Column{
            y: (parent.height - height) / 2 - 4
            x: parent.height - y - height - 12
            spacing: 2
            ThemedIcon {
                id: icon
                height: 64 * root.scale
                width: height
                iconSource: root.icon
                smooth: true
                antialiasing: true
                mipmap: true
            }

            XCText{
                id: title
                x: 12
                text: root.title
                y: icon.height + 8
                onCenter: false
                boldFont: true
                xcFontSize: 18 * root.scale
            }
            XCText{
                id: subtitle
                x: 12
                text: root.subtitle
                y: icon.height + 8
                onCenter: false
                boldFont: false
                xcFontSize: 14 * root.scale
            }
        }
    }   
}
