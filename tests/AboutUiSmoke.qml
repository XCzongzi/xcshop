pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    width: 1000; height: 760; visible: true
    property int stage: 0
    property int backEvents: 0
    property var appWindow: null
    property string savedBackground: ""
    XCFile { id: results }
    Component.onCompleted: results.write(SMOKE_OUTPUT_DIR + "/about-test-result.txt", "RUNNING")
    Loader { id: loader; anchors.fill: parent; sourceComponent: about }
    Component {
        id: applicationWindow
        Main { width: 1000; height: 760 }
    }
    Component {
        id: about
        PageOnAbout {
            onPageEvent: function(signalType, parameters) {
                if (signalType === "About.back") root.backEvents++
            }
        }
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) {
            var result = find(child, name)
            if (result) return result
        }
        return null
    }
    function capture(name) {
        (loader.item as PageOnAbout).grabToImage(function(result) {
            result.saveToFile(SMOKE_OUTPUT_DIR + "/about-" + name + ".png")
        })
    }
    Timer {
        interval: 850; running: true; repeat: true
        onTriggered: {
            try {
                var page = loader.item as PageOnAbout
                var view = root.find(page, "aboutScrollView")
                if (root.stage === 0) {
                    root.check(root.find(page, "aboutCover").status === Image.Ready, "bundled cover did not load")
                    root.check(!page.expanded && view.contentY === 0, "initial cover state")
                    var avatar = root.find(page, "aboutAvatar")
                    root.check(Math.abs(avatar.y + avatar.height * 2 / 3) < 0.1, "avatar overlap ratio")
                    root.check(page.coverHeight > page.height * 0.7, "initial cover is too short")
                    root.capture("cover-dark")
                    UiInput.click(root.find(page, "aboutRevealArea"), page.width / 2, 60)
                } else if (root.stage === 1) {
                    root.check(page.expanded && Math.abs(view.contentY - page.revealOffset) < 1,
                               "click did not reveal profile: expanded=" + page.expanded + ", offset=" + view.contentY + ", expected=" + page.revealOffset)
                    root.check(!root.find(page, "aboutRevealArea").visible, "overlay still blocks links")
                    root.capture("expanded-dark")
                    UiInput.wheel(view, -120)
                } else if (root.stage === 2) {
                    root.check(view.contentY > page.revealOffset + 10, "normal wheel scrolling failed")
                    root.check(String(root.find(page, "aboutGithub").destination) === "https://github.com/XCzongzi", "GitHub URL")
                    root.check(String(root.find(page, "aboutBilibili").destination) === "https://space.bilibili.com/481184316", "bilibili URL")
                    root.check(String(root.find(page, "aboutSponsor").destination) === "https://afdian.com/a/xczongzi", "sponsor URL")
                    view.contentY = view.contentHeight - view.height
                    root.capture("sponsor-dark")
                    UiInput.click(root.find(page, "aboutBack"))
                    root.check(root.backEvents === 1, "back event")
                } else if (root.stage === 3) {
                    loader.active = false
                    root.width = 800; root.height = 500
                    Colors.applyColorScheme("parchment")
                    loader.active = true
                } else if (root.stage === 4) {
                    root.check(!page.expanded && view.contentY === 0, "reentry did not reset cover")
                    root.capture("cover-light-small")
                    UiInput.wheel(view, -120)
                } else if (root.stage === 5) {
                    root.check(page.expanded && Math.abs(view.contentY - page.revealOffset) < 1, "wheel did not reveal profile")
                    root.capture("expanded-light-small")
                    root.width = 480
                    view.contentY = view.contentHeight - view.height
                } else if (root.stage === 6) {
                    var github = root.find(page, "aboutGithub")
                    var bilibili = root.find(page, "aboutBilibili")
                    root.check(bilibili.y > github.y && github.width <= page.width, "narrow cards did not stack")
                    root.check(view.contentY <= view.contentHeight - view.height + 1, "scroll exceeds content after resize")
                    view.contentY = view.contentHeight - view.height
                    root.capture("sponsor-light-narrow")
                } else if (root.stage === 7) {
                    Global.settingsPath = SMOKE_DIR + "/about-settings.json"
                    root.appWindow = applicationWindow.createObject(null)
                    root.hide()
                } else if (root.stage === 8) {
                    var appLoader = root.find(root.appWindow.contentItem, "mainPageLoader")
                    root.savedBackground = root.appWindow.backgroundSource
                    appLoader.item.pageEvent("Start.", { object: "about" })
                } else if (root.stage === 9) {
                    var aboutLoader = root.find(root.appWindow.contentItem, "mainPageLoader")
                    root.check(aboutLoader.sourceComponent === Constants.pageOnAbout, "start-page navigation")
                    root.check(aboutLoader.item.width === root.appWindow.surfaceWidth
                               && aboutLoader.item.height === root.appWindow.surfaceHeight,
                               "about does not cover the full application surface")
                    root.check(aboutLoader.x === 0 && aboutLoader.item.x === 0, "about is offset by workspace sidebar")
                    root.check(root.appWindow.backgroundSource === root.savedBackground, "about changed user background preference")
                    root.appWindow.contentItem.grabToImage(function(result) {
                        result.saveToFile(SMOKE_OUTPUT_DIR + "/about-full-window.png")
                    })
                } else if (root.stage === 10) {
                    var backLoader = root.find(root.appWindow.contentItem, "mainPageLoader")
                    UiInput.click(root.find(backLoader.item, "aboutBack"))
                } else if (root.stage === 11) {
                    root.check(root.find(root.appWindow.contentItem, "mainPageLoader").sourceComponent === Constants.pageOnStart,
                               "return to start page")
                    root.appWindow.close()
                    stop()
                    results.write(SMOKE_OUTPUT_DIR + "/about-test-result.txt", "ABOUT_UI_SMOKE_PASSED")
                    console.log("ABOUT_UI_SMOKE_PASSED")
                    Qt.quit()
                }
                root.stage++
            } catch (error) {
                stop()
                results.write(SMOKE_OUTPUT_DIR + "/about-test-result.txt", "ABOUT_UI_SMOKE_FAILED: " + error)
                console.error("ABOUT_UI_SMOKE_FAILED", error)
                Qt.exit(1)
            }
        }
    }
}
