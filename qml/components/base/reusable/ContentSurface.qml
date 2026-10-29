pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import xcshop

Rectangle {
    id: root

    property bool hoverEffectsEnabled: false
    property Item hoverTarget: root
    property Item backdropSource: Global.mainWindow_backdrop
    property real backdropBlur: 1.0
    readonly property bool hovered: hoverEffectsEnabled && hoverHandler.hovered
    readonly property real backgroundOpacity: Global.backgroundMode === "color" ? 0.38 : 0.44
    property real hoverProgress: hovered ? 1 : 0

    radius: 9
    color: Colors.changeA(Colors.card, backgroundOpacity)
    border.width: 1
    border.color: Colors.changeA(Colors.outline, 0.08)

    Behavior on hoverProgress {
        NumberAnimation {
            duration: 500 / Global.animationSpeed
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: hoverHandler
        parent: root.hoverTarget
        enabled: root.hoverEffectsEnabled && root.enabled
        blocking: false
    }

    // Draw the blurred backdrop below the tint and all foreground controls.
    // The source excludes the cards, so it cannot recursively capture itself.
    Loader {
        anchors.fill: parent
        z: -1
        active: root.visible && root.opacity > 0 && root.hoverProgress > 0 && root.backdropSource !== null
                && root.width > 0 && root.height > 0
        opacity: root.hoverProgress
        sourceComponent: Item {
            id: backdrop
            readonly property int blurPadding: 192
            clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: root.width
                    height: root.height
                    radius: root.radius
                    topLeftRadius: root.topLeftRadius
                    topRightRadius: root.topRightRadius
                    bottomLeftRadius: root.bottomLeftRadius
                    bottomRightRadius: root.bottomRightRadius
                }
            }

            ShaderEffectSource {
                id: capture
                x: -backdrop.blurPadding
                y: -backdrop.blurPadding
                width: root.width + backdrop.blurPadding * 2
                height: root.height + backdrop.blurPadding * 2
                sourceItem: root.backdropSource
                visible: false
                live: true
                textureSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
                sourceRect: {
                    // Track ancestor geometry as well as the card itself so
                    // the crop follows scrolling, panel resizing and motion.
                    var geometry = 0
                    var items = [root, root.backdropSource]
                    for (var index = 0; index < items.length; ++index) {
                        var item = items[index]
                        while (item) {
                            geometry += item.x + item.y + item.width + item.height
                                    + item.scale + item.rotation
                            item = item.parent
                        }
                    }
                    if (!isFinite(geometry) || !root.backdropSource)
                        return Qt.rect(0, 0, 0, 0)
                    return root.mapToItem(root.backdropSource,
                                          Qt.rect(x, y, width, height))
                }
            }

            MultiEffect {
                x: capture.x
                y: capture.y
                width: capture.width
                height: capture.height
                source: capture
                blurEnabled: true
                blurMax: 64
                blurMultiplier: 2.5
                blur: root.backdropBlur
                autoPaddingEnabled: false
            }
        }
    }
}
