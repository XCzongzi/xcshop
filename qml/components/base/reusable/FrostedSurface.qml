pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import xcshop

Rectangle {
    id: root
    readonly property Item pageBackdrop: Global.mainWindow_popupBackdrop || Global.mainWindow_backdrop
    property Item backdropAnchor: null
    property Item backdropSource: {
        // Overlay popups can sample their containing dialog without capturing themselves.
        var item = backdropAnchor
        while (item) {
            if (item.objectName === "popupPanel") return item
            item = item.parent
        }
        return pageBackdrop
    }
    property color tint: Colors.popup
    readonly property bool blurEnabled: GraphicsInfo.api !== GraphicsInfo.Software
            && backdropSource !== null

    radius: 7
    color: Colors.changeA(tint, blurEnabled ? 0.68 : 0.90)
    border.width: 1
    border.color: Colors.changeA(Colors.outline, 0.14)
    // Fade the finished material as one image, including its translucent tint.
    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software

    function sampleRect(source, region) {
        if (!source) return Qt.rect(0, 0, 0, 0)
        var geometry = 0
        var items = [root, source]
        for (var index = 0; index < items.length; ++index) {
            var item = items[index]
            while (item) {
                geometry += item.x + item.y + item.width + item.height + item.scale + item.rotation
                item = item.parent
            }
        }
        return isFinite(geometry) ? root.mapToItem(source, region) : Qt.rect(0, 0, 0, 0)
    }

    // Shadow a clean silhouette, not the captured backdrop or foreground controls.
    Loader {
        // Keep the exterior shadow outside the material's layer bounds.
        parent: root.parent
        anchors.fill: root
        z: root.z - 1
        visible: root.visible
        opacity: root.opacity
        scale: root.scale
        rotation: root.rotation
        transformOrigin: root.transformOrigin
        active: root.visible && GraphicsInfo.api !== GraphicsInfo.Software
        sourceComponent: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 6
            shadowBlur: 0.65
            shadowColor: Colors.changeA(Colors.shadow, 0.40)
            source: Rectangle {
                width: root.width; height: root.height
                visible: false
                color: root.tint
                topLeftRadius: root.topLeftRadius
                topRightRadius: root.topRightRadius
                bottomLeftRadius: root.bottomLeftRadius
                bottomRightRadius: root.bottomRightRadius
            }
        }
    }
    // Only the backdrop is blurred; labels, borders and controls stay sharp.
    Loader {
        anchors.fill: parent
        z: -1
        active: root.visible && root.blurEnabled && root.width > 0 && root.height > 0
        sourceComponent: Item {
            id: backdrop
            readonly property int padding: 192
            clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    visible: false
                    width: root.width
                    height: root.height
                    topLeftRadius: root.topLeftRadius
                    topRightRadius: root.topRightRadius
                    bottomLeftRadius: root.bottomLeftRadius
                    bottomRightRadius: root.bottomRightRadius
                }
            }
            Item {
                id: capture
                x: -backdrop.padding; y: -backdrop.padding
                width: root.width + backdrop.padding * 2
                height: root.height + backdrop.padding * 2
                visible: false
                // A dropdown may extend beyond its dialog. Composite the page
                // beneath the dialog crop so those regions are blurred too.
                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: root.backdropSource !== root.pageBackdrop ? root.pageBackdrop : null
                    visible: sourceItem !== null
                    live: true
                    textureSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
                    sourceRect: root.sampleRect(sourceItem, Qt.rect(capture.x, capture.y, width, height))
                }
                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: root.backdropSource
                    live: true
                    textureSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
                    sourceRect: root.sampleRect(sourceItem, Qt.rect(capture.x, capture.y, width, height))
                }
            }
            // Retain some background variation through the frosted surface.
            MultiEffect {
                x: capture.x; y: capture.y
                width: capture.width; height: capture.height
                source: capture
                blurEnabled: true
                blurMax: 64
                blurMultiplier: 2.5
                blur: 0.5
                autoPaddingEnabled: false
            }
        }
    }
}
