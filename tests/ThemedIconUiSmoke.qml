pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    x: GraphicsInfo.api === GraphicsInfo.Software ? -10000 : 0
    y: GraphicsInfo.api === GraphicsInfo.Software ? -10000 : 0
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint | Qt.WindowDoesNotAcceptFocus
    width: 1024; height: 640
    color: "#697784"
    property int modeIndex: 0
    property bool applied: false
    property bool pending: false
    property bool swapped: false
    property int captures: 0
    readonly property var modes: [
        "midnight", "slate", "violet", "forest", "amber", "rose",
        "cloud", "glacier", "lavender", "mint", "parchment", "blush",
        "custom-text", "swap-colored", "restore-white"
    ]
    readonly property string output: SMOKE_OUTPUT_DIR + "/theme-qa/"
            + (GraphicsInfo.api === GraphicsInfo.Software ? "software" : "gpu")
    readonly property var icons: [
        {file: "typeBar/Global_light.png", tint: true},
        {file: "typeBar/UI_light.png", tint: true},
        {file: "typeBar/Item_light.png", tint: true},
        {file: "typeBar/Cost_light.png", tint: true},
        {file: "typeBar/Display_light.png", tint: true},
        {file: "typeBar/Extra_light.png", tint: true},
        {file: "element/Bar/newFile_light.png", tint: true},
        {file: "element/Bar/newMenu_light.png", tint: true},
        {file: "element/File_light.png", tint: true, folder: true},
        {file: "titleBar/close.png", tint: true},
        {file: "titleBar/maximize.png", tint: true},
        {file: "titleBar/minimize.png", tint: true},
        {file: "titleBar/restore.png", tint: true},
        {file: "controls/about.png", tint: true},
        {file: "controls/settings.png", tint: true},
        {file: "controls/new_project.png", tint: true},
        {file: "controls/open_project.png", tint: true},
        {file: "controls/expand_up.png", tint: true},
        {file: "controls/expand_down.png", tint: true},
        {file: "element/UI.png", tint: false},
        {file: "element/Item.png", tint: false}
    ]
    XCFile { id: file }
    Rectangle {
        id: frame
        anchors.fill: parent
        color: root.color
        NumberAnimation on opacity { from: 0.999; to: 1; duration: 500; loops: Animation.Infinite }
        Grid {
            x: 24; y: 24; columns: 6; spacing: 12
            Repeater {
                id: pairs
                model: root.icons
                delegate: Item {
                    id: pair
                    required property int index
                    required property var modelData
                    width: 150; height: 138
                    readonly property bool substituted: index === 0 && root.swapped
                    readonly property string sourcePath: "qrc:/assets/gui/" + (substituted ? "element/UI.png" : modelData.file)
                    readonly property string referencePath: "qrc:/assets/gui/" + (substituted ? "element/UI.png" : modelData.reference || modelData.file)
                    readonly property bool expectsTint: modelData.tint && !substituted
                    readonly property var glyph: actual.item ? root.findIcon(actual.item) : null
                    property alias reference: original
                    Loader {
                        id: actual
                        x: 8; y: 12; width: 48; height: 48
                        sourceComponent: pair.modelData.folder ? folder : button
                        Component {
                            id: button
                            ImageButton {
                                imageSource: pair.sourcePath
                                btnSize: 48; imgSize: 48
                                enabled: false
                            }
                        }
                        Component {
                            id: folder
                            FileButton { width: 48; height: 48; icon: "File_light"; enabled: false }
                        }
                    }
                    Image {
                        id: original
                        x: 82 + (pair.glyph ? pair.glyph.x : 0)
                        y: 12 + (pair.glyph ? pair.glyph.y : 0)
                        width: pair.glyph ? pair.glyph.width : 48
                        height: pair.glyph ? pair.glyph.height : 48
                        sourceSize: pair.glyph ? pair.glyph.sourceSize : Qt.size(48, 48)
                        fillMode: pair.glyph ? pair.glyph.fillMode : Image.Stretch
                        source: pair.referencePath
                    }
                    Text {
                        y: 78; width: parent.width
                        text: pair.modelData.file
                        color: "white"; font.pixelSize: 10
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }
    }
    function check(ok, message) {
        if (!ok) throw new Error(modes[modeIndex] + ": " + message)
    }
    function findIcon(item) {
        if (item.iconSource !== undefined && item.monochrome !== undefined) return item
        for (var child of item.children) {
            var icon = findIcon(child)
            if (icon) return icon
        }
        return null
    }
    function physicalRect(item) {
        var point = item.mapToItem(frame, 0, 0), scale = Screen.devicePixelRatio
        return Qt.rect(Math.round(point.x * scale), Math.round(point.y * scale),
                       Math.round(item.width * scale), Math.round(item.height * scale))
    }
    function verify(path) {
        for (var index = 0; index < pairs.count; ++index) {
            var pair = pairs.itemAt(index), glyph = pair.glyph
            check(glyph && glyph.status === Image.Ready && pair.reference.status === Image.Ready,
                  pair.modelData.file + " was not loaded")
            check(glyph.source.toString() === pair.referencePath, pair.modelData.file + " did not use the white source")
            check(glyph.monochrome === pair.expectsTint, pair.modelData.file + " was classified incorrectly")
            var tinted = Colors.isLight && pair.expectsTint
            check(tinted ? Qt.colorEqual(glyph.color, Colors.text) : glyph.color.a === 0,
                  pair.modelData.file + " has the wrong tint")
            var pixels = UiInput.iconPixelDifference(path, physicalRect(glyph), physicalRect(pair.reference),
                                                    Colors.text, tinted)
            check(pixels.samples > 0 && pixels.error <= 4,
                  pair.modelData.file + " rendered RGB error=" + pixels.error + " samples=" + pixels.samples)
        }
    }
    function fail(error) { console.error("THEMED_ICON_UI_SMOKE_FAILED: " + error); Qt.exit(1) }
    Component.onCompleted: {
        Global.backgroundMode = "color"
        Global.settingsPath = SMOKE_DIR + "/icon-settings.json"
        file.folder(output)
        timer.start()
    }
    Timer {
        id: timer
        interval: 180; repeat: true
        onTriggered: {
            if (root.pending) return
            try {
                if (!root.applied) {
                    var mode = root.modes[root.modeIndex]
                    Colors.applyColorScheme(root.modeIndex < 12 ? mode : "cloud")
                    if (mode === "custom-text") Colors.paletteText = "#62859b"
                    root.swapped = mode === "swap-colored"
                    root.applied = true
                    return
                }
                root.pending = true
                var path = root.output + "/icons-" + root.modes[root.modeIndex] + ".png"
                frame.grabToImage(function(result) {
                    try {
                        root.check(result.saveToFile(path), "screenshot could not be saved")
                        root.verify(path)
                        ++root.captures
                        if (++root.modeIndex === root.modes.length) {
                            console.log("THEMED_ICON_UI_SMOKE_PASSED: 21 icons, 6 dark/6 light themes, exact text RGB, original dark pixels, colored assets preserved, custom text and source swaps; screenshots=" + root.captures)
                            Qt.exit(0)
                            return
                        }
                        root.applied = false
                        root.pending = false
                    } catch (error) { root.fail(error) }
                }, Qt.size(frame.width, frame.height))
            } catch (error) { root.fail(error) }
        }
    }
}
