import QtQuick
import QtQuick.Controls as Controls
import xcshop

Controls.ScrollView {
    id: root
    contentWidth: availableWidth
    clip: true
    Controls.ScrollBar.vertical: XCScrollBar {}
    Controls.ScrollBar.horizontal: XCScrollBar {
        policy: Controls.ScrollBar.AlwaysOff
    }
}
