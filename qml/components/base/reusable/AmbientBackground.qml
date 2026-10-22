import QtQuick
import Qt5Compat.GraphicalEffects
import xcshop

Item {
    id: root
    property bool animated: false
    clip: true

    // Compose real linear/radial gradients first, then soften the complete
    // result with a Gaussian blur.
    Item {
        id: backgroundGradientSource
        anchors.fill: parent
        visible: false
        property real flowPhase: 0

        NumberAnimation on flowPhase {
            from: 0
            to: Math.PI * 2
            duration: 18000 / Global.animationSpeed
            loops: Animation.Infinite
            easing.type: Easing.Linear
            running: root.animated && root.visible
        }

        Rectangle {
            anchors.fill: parent
            color: Global.backgroundMode === "color"
                   ? Colors.background_n : Colors.transparent
        }

        LinearGradient {
            anchors.fill: parent
            start: Qt.point(width * (0.03 + 0.05 * Math.sin(backgroundGradientSource.flowPhase)),
                            height * (0.04 + 0.04 * Math.cos(backgroundGradientSource.flowPhase * 2)))
            end: Qt.point(width * (0.96 + 0.03 * Math.cos(backgroundGradientSource.flowPhase)),
                          height * (0.94 + 0.05 * Math.sin(backgroundGradientSource.flowPhase * 2)))
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Colors.changeA(Qt.darker(Colors.border, 1.35),
                                          Global.backgroundMode === "color" ? 0.34 : 0.20)
                }
                GradientStop {
                    position: 0.24
                    color: Colors.changeA(Colors.border,
                                          Global.backgroundMode === "color" ? 0.22 : 0.14)
                }
                GradientStop {
                    position: 0.52
                    color: Colors.changeA(Colors.background_n, 0.0)
                }
                GradientStop {
                    position: 0.78
                    color: Colors.changeA(Qt.lighter(Colors.foreground, 1.35),
                                          Global.backgroundMode === "color" ? 0.28 : 0.16)
                }
                GradientStop {
                    position: 1.0
                    color: Colors.changeA(Qt.lighter(Colors.border, 1.22),
                                          Global.backgroundMode === "color" ? 0.18 : 0.10)
                }
            }
        }

        RadialGradient {
            anchors.fill: parent
            horizontalOffset: width * (0.24 + 0.10 * Math.sin(backgroundGradientSource.flowPhase))
            verticalOffset: height * (-0.20 + 0.08 * Math.cos(backgroundGradientSource.flowPhase * 2))
            horizontalRadius: width * (0.66 + 0.05 * Math.cos(backgroundGradientSource.flowPhase))
            verticalRadius: height * (0.82 + 0.05 * Math.sin(backgroundGradientSource.flowPhase))
            angle: -12 + 10 * Math.sin(backgroundGradientSource.flowPhase * 2)
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Colors.changeA(Qt.lighter(Colors.border, 1.45),
                                          Global.backgroundMode === "color" ? 0.30 : 0.18)
                }
                GradientStop {
                    position: 0.34
                    color: Colors.changeA(Colors.border,
                                          Global.backgroundMode === "color" ? 0.20 : 0.12)
                }
                GradientStop {
                    position: 0.68
                    color: Colors.changeA(Qt.lighter(Colors.foreground, 1.18),
                                          Global.backgroundMode === "color" ? 0.08 : 0.05)
                }
                GradientStop {
                    position: 1.0
                    color: Colors.transparent
                }
            }
        }
    }

    GaussianBlur {
        anchors.fill: parent
        source: backgroundGradientSource
        radius: 16
        samples: 33
        transparentBorder: false
        // The source moves continuously, so caching would freeze the flow
        // or force an unnecessary extra texture update on every frame.
        cached: false
    }
}
