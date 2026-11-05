pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import xcshop

Item {
    id: root
    required property string imageName
    required property string imageSource
    property var schemes: []
    property bool removable: false
    readonly property bool selected: Global.backgroundImage === imageSource
    signal chosen()
    signal themeChosen(string schemeId)
    signal removeRequested()
    signal revealRequested()
    objectName: "backgroundCard_" + imageName
    height: preview.height + 32

    Rectangle {
        id: previewMask
        width: preview.width; height: preview.height
        radius: 10
        layer.enabled: true
        visible: false
    }

    Image {
        id: preview
        width: parent.width
        height: width * 9 / 16
        source: root.imageSource
        sourceSize.width: Math.ceil(width * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: previewMask
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chosen()
        }
    }
    Rectangle {
        anchors.fill: preview
        visible: root.selected
        color: "transparent"
        radius: 10
        border.width: 2
        border.color: Colors.themeColor
    }
    Rectangle {
        visible: root.selected
        anchors.right: preview.right
        anchors.top: preview.top
        anchors.margins: 6
        width: 48; height: 22; radius: 6
        color: Colors.accentFill
        XCText {
            xcText: "当前"
            xcFontSize: 11
            textColor: Colors.accentContent
        }
    }
    XCText {
        y: preview.height + 6
        width: Math.max(0, parent.width - themeSwatches.width - 8)
        height: 20
        verticalAlignment: Text.AlignVCenter
        visible: !root.removable
        xcText: root.imageName; onCenter: false; xcFontSize: 13
    }
    Row {
        id: themeSwatches
        anchors.right: parent.right
        y: preview.height + 7
        spacing: 0
        visible: !root.removable
        Repeater {
            model: root.schemes
            delegate: Rectangle {
                id: swatch
                required property int index
                required property string modelData
                readonly property var scheme: Colors.colorSchemes.filter(function(s) { return s.id === swatch.modelData })[0]
                width: height * 1.5
                height: 18
                topLeftRadius: index === 0 ? 6 : 0
                bottomLeftRadius: index === 0 ? 6 : 0
                topRightRadius: index === root.schemes.length - 1 ? 6 : 0
                bottomRightRadius: index === root.schemes.length - 1 ? 6 : 0
                color: scheme.foreground
                MouseArea {
                    id: swatchMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.themeChosen(swatch.modelData)
                }
                XCToolTip {
                    active: swatchMouse.containsMouse
                    delay: 0
                    text: "应用“" + swatch.scheme.name + "”主题及强调色"
                }
            }
        }
    }
    Row {
        y: preview.height + 3; spacing: 6
        visible: root.removable
        ActionButton { text: "查看文件"; height: 26; textSize: 11; onClicked: root.revealRequested() }
        ActionButton { text: "删除"; height: 26; textSize: 11; destructive: true; onClicked: root.removeRequested() }
    }
}
