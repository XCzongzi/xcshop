import QtQuick
import xcshop

// Workspace chrome shares the same tint and permanent backdrop blur.
ContentSurface {
    radius: 0
    color: Colors.panel
    border.width: 0
    hoverProgress: 1
    backdropBlur: 0.3
}
