pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Rectangle{
    id: root
    property int uiscale: 1
    property int containerType: 0
    color: Colors.transparent

    width: containerImage.sourceSize.width * uiscale
    height: containerImage.sourceSize.height * uiscale


    Image{
        id: containerImage
        anchors.fill: parent
        source: "qrc:/assets/minecraft/gui/container/" + root.containerType + ".png"
        fillMode: Image.PreserveAspectFit
        smooth: false
        mipmap: false
    }

    Repeater{
        model: Constants.containerCount[root.containerType]
        delegate: ItemSlot{
            required property int index
            required property var model
            size: 16 * root.uiscale
            selectionId: "item"

            x: Constants.containerSlot[root.containerType][index][0] * root.uiscale
            y: Constants.containerSlot[root.containerType][index][1] * root.uiscale
        }
    }
}
