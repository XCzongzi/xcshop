import QtQuick
import xcshop
import "../../../../js/DisplayFormatting.js" as Formatting
import "../../../../js/WorkspaceSchema.js" as Schema

Item {
    id: root
    property var format: Schema.display()
    property int demoElementCount: 3
    property int demoOperationCount: 2
    property real maximumWidth: 900
    readonly property var renderedComponent: Formatting.demo(format, demoOperationCount, demoElementCount)
    readonly property string renderedHtml: Formatting.html(renderedComponent)
    implicitWidth: Math.min(maximumWidth, Math.max(126, tooltipText.implicitWidth + 36))
    implicitHeight: Math.max(48, tooltipText.contentHeight + 32)
    width: implicitWidth
    height: implicitHeight
    BorderImage {
        anchors.fill: parent
        source: "qrc:/assets/minecraft/gui/item_lore/background.png"
        opacity: 0.76
        border {
            left: 10
            top: 10
            right: 10
            bottom: 10
        }
    }
    BorderImage {
        anchors.fill: parent
        source: "qrc:/assets/minecraft/gui/item_lore/frame.png"
        border {
            left: 10
            top: 10
            right: 10
            bottom: 10
        }
    }
    Text {
        id: tooltipText
        x: 18
        y: 16
        width: root.width - 36
        text: "…<br>" + root.renderedHtml
        textFormat: Text.RichText
        wrapMode: Text.Wrap
        color: "#ffffff"
        font.family: "Microsoft YaHei"
        font.pixelSize: 15
        lineHeight: 1.08
    }
}
