pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PanelSurface {
    id: typeBar
    height: parent.height
    width: Constants.typeBarWidth
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
        width:3
        height: Constants.typeBarWidth - 1
        x: 2
        y: (typeBar.currentType == 0)? 1 : 3 + typeBar.currentType * Constants.typeBarWidth
        color: Colors.border
        radius: 2
        Behavior on y{
            NumberAnimation{
                duration: 120 / Global.animationSpeed
                easing.type: Easing.InOutQuad
            }
        }
    }

    component TypeButtonComponent: ImageButton{
        id: typeButton
        property string typeValue
        freeze: typeBar.freeze
        btnSize: Constants.typeBarWidth
        imgSize: Constants.typeBarWidth * 3/4
        btnRadius: 4
        imageSource: "qrc:/assets/gui/typeBar/" + typeValue + "_light.png"
        btnSelected:(typeBar.currentType == z) ? true : false
        onClicked: {
            if (typeValue == "更多") return
            typeBar.currentType = z
            typeBar.typeBtnClicked(typeValue)
        }
        XCToolTip {
            active: typeButton.hovered
            text: typeButton.typeValue
            delay: 0
            beside: true
        }
    }

    TypeButtonComponent{
        id: typeButtonTotal
        z: 0
        y: 1
        typeValue: "Global"
    }
    Rectangle{
        width: parent.width
        y: Constants.typeBarWidth
        height: 2
        color: Colors.isLight ? Colors.outline : "white"
    }

    Column{
        id: typeColumn
        width: parent.width
        height: parent.height - Constants.typeBarWidth
        y: Constants.typeBarWidth + 2

        TypeButtonComponent{
            id: typeButtonUI
            z: 1
            typeValue: "UI"
        }
        TypeButtonComponent{
            id: typeButtonItem
            z: 2
            typeValue: "Item"
        }
        TypeButtonComponent{
            id: typeButtonCost
            z: 3
            typeValue: "Cost"
        }
        TypeButtonComponent{
            id: typeButtonDisplay
            z: 4
            typeValue: "Display"
        }

    }

    TypeButtonComponent{
        id: typeButtonExtra
        freeze: false
        z: 12
        y: parent.height - height
        imageSource: "qrc:/assets/gui/typeBar/Extra_light.png"
        typeValue: "更多"

        onClicked:{
            typeBar.extraMenuOpened = !typeBar.extraMenuOpened
            typeBar.focus_on(typeBar.extraMenuOpened)
        }
    }
    PanelSurface{
        id:extraMenu
        z: 13
        visible: typeBar.extraMenuOpened
        opacity: visible ? 1 : 0
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
