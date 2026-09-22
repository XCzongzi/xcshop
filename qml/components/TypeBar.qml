import QtQuick
import xcshop

Rectangle {
    id: typeBar
    height: parent.height
    width: 65
    color: Colors.foreground
    opacity: 0
    enabled: isEnabled

    signal typeBtnClicked(string typeName)
    signal focus_on(bool on)
    signal extraButton_clicked(string type)

    property bool isEnabled
    property bool freeze: false
    property bool extraMenuOpened: false

    property int currentType: 0     //用z坐标作为当前类型的标号

    function enable(animation = false){
        isEnabled = true
        x_animation.enabled = animation
        opa_animation.enabled = animation
        opacity = 1
        x = 0
    }
    function disable(animation = false){
        isEnabled = false
        extraMenuOpened = false
        x_animation.enabled = animation
        opa_animation.enabled = animation
        opacity = 0
        x = -width
    }

    Behavior on x {
        id: x_animation
        NumberAnimation{
            easing.type: Easing.InQuint
            duration: 370 / Global.animationSpeed
        }
    }
    Behavior on opacity{
        id: opa_animation
        NumberAnimation{
            easing.type: Easing.InQuint
            duration: 370 / Global.animationSpeed
        }
    }

    Rectangle{
        id: currentTypeRect
        z: 10
        width:5
        height: 64
        x: 2
        y: (typeBar.currentType == 0)? 1 : 3 + typeBar.currentType*64
        color: Colors.border
        //radius: 5
        Behavior on y{
            NumberAnimation{
                duration: 120 / Global.animationSpeed
                easing.type: Easing.InOutQuad
            }
        }
    }


    ImageButton{
        id: typeButtonTotal
        freeze: typeBar.freeze
        z: 0
        y: 1
        btnSize: 64
        imgSize: 48
        btnRadius: 0
        imageSource: "qrc:/assets/gui/typeBar/Total.png"
        btnSelected:(typeBar.currentType == z) ? true : false
        onClicked: {
            typeBar.currentType = z
            setColor()
            typeBar.typeBtnClicked("Total")
        }
    }
    Rectangle{
        width: parent.width
        y: 65
        height: 2
        color: "#FFFFFF"
    }

    Column{
        id: typeColumn
        width: parent.width
        height: parent.height - 66
        y: 67

        ImageButton{
            id: typeButtonUI
            freeze: typeBar.freeze
            z: 1
            y: 0
            btnSize: 64
            imgSize: 48
            btnRadius: 0
            imageSource: "qrc:/assets/gui/typeBar/UI_" + Colors.gui_theme + ".png"

            btnSelected:(typeBar.currentType == z) ? true : false
            onClicked: {
                typeBar.currentType = z
                setColor()
                typeBar.typeBtnClicked("UI")
            }
        }
        ImageButton{
            id: typeButtonItem
            freeze: typeBar.freeze
            z: 2
            y: 64
            btnSize: 64
            imgSize: 48
            btnRadius: 0
            imageSource: "qrc:/assets/gui/typeBar/Item.png"

            btnSelected:(typeBar.currentType == z) ? true : false
            onClicked: {
                typeBar.currentType = z
                setColor()
                typeBar.typeBtnClicked("Item")
            }
        }
        ImageButton{
            id: typeButtonCost
            freeze: typeBar.freeze
            z: 3
            y: 128
            btnSize: 64
            imgSize: 48
            btnRadius: 0
            imageSource: "qrc:/assets/gui/typeBar/Cost.png"

            btnSelected:(typeBar.currentType == z) ? true : false
            onClicked: {
                typeBar.currentType = z
                setColor()
                typeBar.typeBtnClicked("Cost")
            }
        }
        ImageButton{
            id: typeButtonDisplay
            freeze: typeBar.freeze
            z: 4
            y: 192
            btnSize: 64
            imgSize: 48
            btnRadius: 0
            imageSource: "qrc:/assets/gui/typeBar/Display.png"

            btnSelected:(typeBar.currentType == z) ? true : false
            onClicked: {
                typeBar.currentType = z
                setColor()
                typeBar.typeBtnClicked("Display")
            }
        }

    }

    ImageButton{
        id: typeButtonExtra
        freeze: typeBar.freeze
        z: 12
        y: parent.height - height
        btnSize: 64
        imgSize: 48
        btnRadius: 32
        imageSource: "qrc:/assets/gui/typeBar/Display.png"

        onClicked:{
            typeBar.extraMenuOpened = !typeBar.extraMenuOpened
            typeBar.focus_on(typeBar.extraMenuOpened)
        }
    }
    Rectangle{
        id:extraMenu
        z: 13
        visible: typeBar.extraMenuOpened
        opacity: visible ? 1 : 0
        color: Colors.background
        radius: 8
        x: 64
        y: typeButtonExtra.y + typeButtonExtra.height - height
        width: 200 + 8
        height:extra_plot.height + 8
        border.width: 1
        border.color: Colors.text
        Behavior on opacity{
            NumberAnimation{
                duration: 200 / Global.animationSpeed
            }
        }
        Column{
            id: extra_plot
            width: parent.width - 8
            anchors.centerIn: parent
            TextButton{
                text:"关于"
                width: parent.width
                radius: 6
                textSize: 14
                boldFont:false
                heightBorderSize: 3
                onClicked:{
                    typeButtonExtra.clicked()
                    typeBar.extraButton_clicked("about")
                }
            }
            TextButton{
                text:"设置"
                width: parent.width
                radius: 6
                textSize: 14
                boldFont:false
                heightBorderSize: 3
                onClicked:{
                    typeButtonExtra.clicked()
                    typeBar.extraButton_clicked("settings")
                }
            }
        }
    }
    Rectangle{
        id: shadow
        z: 11
        visible: typeBar.extraMenuOpened
        opacity: visible ? 1 : 0
        width: Global.window_width + typeBar.width
        height: Global.window_height
        color: Colors.shadow
        MouseArea{
            enabled: typeBar.extraMenuOpened
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                typeButtonExtra.clicked()
            }
        }
        Behavior on opacity{
            NumberAnimation{
                duration: 200 / Global.animationSpeed
            }
        }
    }

}
