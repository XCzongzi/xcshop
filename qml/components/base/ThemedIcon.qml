import QtQuick
import QtQuick.Controls.impl as Impl
import xcshop

// Only known monochrome UI assets participate in theme tinting. Item textures,
// colored element badges and user images retain their original pixels.
Impl.IconImage {
    id: root
    property string iconSource: ""
    property bool tintIcon: true
    property color tintColor: Colors.text
    readonly property bool monochrome: Colors.isMonochromeUiIcon(iconSource)

    source: Colors.whiteUiIconSource(iconSource)
    color: Colors.isLight && tintIcon && monochrome ? tintColor : Colors.transparent
}
