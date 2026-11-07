pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    visible: true
    width: 1; height: 1
    property var appWindow: null
    property int stage: 0
    property int ticks: 0
    property bool capturing: false
    property var marker: null
    Component { id: application; Main { width: 1000; height: 760 } }
    Component { id: backgroundMarker; Rectangle { x: 20; y: 60; width: 48; height: 48; color: "#fe2387"; z: 10 } }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) {
            var result = find(child, name)
            if (result) return result
        }
        return null
    }
    function hoverSurface(item) {
        if (item instanceof ContentSurface && item.hoverEffectsEnabled) return item
        for (var child of item.children) {
            var result = hoverSurface(child)
            if (result) return result
        }
        return null
    }
    function checkScene() {
        var scene = appWindow.scene
        var foreground = find(appWindow.contentItem, "workspaceForeground")
        check(appWindow.backdrop.parent === scene && foreground.parent === scene,
              "the actual background and content must share one scene")
        check(Global.mainWindow_popupBackdrop === scene, "dialog capture must use the actual scene")
        var display = find(appWindow.contentItem, "windowSceneDisplay")
        check(display.sourceItem === scene && display.hideSource && display.visible,
              "GPU output must replace the source scene")
        function noBackgroundCopies(item) {
            check(item.sourceItem !== appWindow.backdrop || !item.visible,
                  "a background sampling texture must not be displayed as another page background")
            for (var child of item.children) noBackgroundCopies(child)
        }
        noBackgroundCopies(appWindow.contentItem)
        var loader = find(appWindow.contentItem, "mainPageLoader")
        if (loader.sourceComponent === Constants.pageOnStart) {
            var origin = loader.item.mapToItem(scene, 0, 0)
            check(origin.x === 0 && origin.y === 0 && loader.item.width === scene.width
                  && loader.item.height === scene.height, "start page must match the background viewport")
        }
    }
    function capture(name) {
        capturing = true
        var started = appWindow.contentItem.grabToImage(function(result) {
            try {
                var path = SMOKE_OUTPUT_DIR + "/background-scene-" + name + ".png"
                check(result.saveToFile(path), "failed to save " + name)
                if (name === "marker") {
                    var point = marker.mapToItem(appWindow.contentItem, marker.width / 2, marker.height / 2)
                    var dpr = appWindow.screen.devicePixelRatio
                    check(Qt.colorEqual(UiInput.imageColor(path, Math.round(point.x * dpr), Math.round(point.y * dpr)), marker.color),
                          "displayed background must preserve the actual scene's pixel positions and colors after resize")
                }
                stage++
                capturing = false
            } catch (error) { fail(error) }
        })
        check(started, "failed to capture " + name)
    }
    function fail(error) { console.error("BACKGROUND_SCENE_UI_SMOKE_FAILED", error); Qt.exit(1) }
    Component.onCompleted: {
        appWindow = application.createObject(null)
        Global.backgroundMode = "image"
        Global.backgroundImage = "qrc:/assets/backgrounds/望夜城.png"
        Global.backgroundBlur = 0.7
    }
    Timer {
        interval: 450; running: true; repeat: true
        onTriggered: {
            if (root.capturing) return
            try {
                root.check(++root.ticks < 65, "background test timed out at " + root.stage)
                var loader = root.find(root.appWindow.contentItem, "mainPageLoader")
                var entrance = root.find(root.appWindow.contentItem, "workspaceEntrance")
                switch (root.stage) {
                case 0:
                    if (loader.item.opacity < 1) return
                    root.checkScene()
                    root.capture("start")
                    break
                case 1:
                    loader.item.openCreation()
                    root.stage++
                    break
                case 2:
                    if (loader.item.creationProgress < 1) return
                    var surface = root.hoverSurface(loader.item)
                    root.check(surface && surface.backdropSource === root.appWindow.backdrop,
                               "creation panel must blur the actual background including its gradient")
                    UiInput.hover(surface.hoverTarget)
                    root.stage++
                    break
                case 3:
                    root.checkScene()
                    root.capture("creation-hover")
                    break
                case 4:
                    loader.item.pageEvent("Popup.show", {component: Constants.popupNotice,
                        properties: {title: "背景取样", content: "弹窗与创建面板共享真实背景。"}})
                    root.stage++
                    break
                case 5:
                    var panel = root.find(root.appWindow.contentItem, "popupPanel")
                    if (!panel || panel.opacity < 1) return
                    var ancestor = panel.parent
                    while (ancestor) {
                        root.check(ancestor !== root.appWindow.scene, "dialog must stay outside its own capture")
                        ancestor = ancestor.parent
                    }
                    root.check(root.find(root.appWindow.contentItem, "popupBackdropBlur").active,
                               "GPU dialog must retain backdrop blur")
                    root.capture("popup")
                    break
                case 6:
                    root.find(root.appWindow.contentItem, "noticeConfirmButton").clicked()
                    loader.item.closeCreation()
                    root.stage++
                    break
                case 7:
                    if (root.find(root.appWindow.contentItem, "popupPanel") || loader.item.creationProgress > 0) return
                    loader.item.pageEvent("Start.", {object: "settings"})
                    root.stage++
                    break
                case 8:
                    if (entrance.busy || loader.sourceComponent !== Constants.pageOnSettings) return
                    root.checkScene()
                    root.capture("settings")
                    break
                case 9:
                    loader.item.pageEvent("Settings.back", {})
                    root.stage++
                    break
                case 10:
                    if (loader.sourceComponent !== Constants.pageOnStart || loader.item.opacity < 1) return
                    root.appWindow.width += 160
                    root.appWindow.height += 90
                    root.stage++
                    break
                case 11:
                    root.checkScene()
                    root.find(root.appWindow.contentItem, "workspaceForeground").visible = false
                    root.marker = backgroundMarker.createObject(root.appWindow.backdrop)
                    root.stage++
                    break
                case 12:
                    root.capture("marker")
                    break
                case 13:
                    console.log("BACKGROUND_SCENE_UI_SMOKE_PASSED")
                    Qt.quit()
                }
            } catch (error) { root.fail(error) }
        }
    }
}
