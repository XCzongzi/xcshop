import QtQuick
import xcshop

Rectangle{
    id: root
    color: Colors.foreground
    height: 36
    width: text.x + text.width + 16
    radius: 8
    border.width: 1
    border.color: Colors.glass_highlight

    property string text
    property string icon

    signal clicked()

    layer.enabled: true
    layer.effect:XCShadow{}
    Behavior on color{
            ColorAnimation{
                duration: 50
            }
        }
    LightEffect{
        lightSource_r: 18
        lightSource_x:mouseArea.mouseX
        lightSource_y:mouseArea.mouseY
        blur: 0.8
    }
    ReusableMouseArea{
        id: mouseArea
        onClicked:{
            root.clicked()
        }
    }

    Image{
        id:img
        source: root.icon
        height: root.height - 16
        width: height
        x: 16
        y: 8
        smooth: true
        antialiasing: true
        mipmap: true
    }
    XCText{
        id:text
        x: img.x + img.width + 8
        xcFontSize: img.height - 2
        text: root.text
        boldFont: false
    }
}
