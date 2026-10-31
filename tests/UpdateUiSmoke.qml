pragma ComponentBehavior: Bound
import QtQuick
import xcshop

Main {
    id: root
    width: 1100
    height: 800
    property int stage: 0
    property int ticks: 0
    property real versionRowHeight: 0
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var child of item.children) {
            var match = find(child, name)
            if (match) return match
        }
        return null
    }
    function capture(name) {
        contentItem.grabToImage(function(result) {
            result.saveToFile(SMOKE_OUTPUT_DIR + "/update-" + name + ".png")
        })
    }
    Timer {
        interval: 400
        repeat: true
        running: true
        onTriggered: {
            try {
                if (++root.ticks > 60) throw new Error("timed out at stage " + root.stage)
                var notice = root.find(root.contentItem, "updateNotice")
                var loader = root.find(root.contentItem, "mainPageLoader")
                if (root.stage === 0) {
                    Updates.check()
                } else if (root.stage === 1) {
                    if (!notice || !notice.opened) return
                    root.check(notice.title === "发现新版本 v0.2.0", "startup notice missing")
                    root.check(root.find(notice, "noticeDismissButton").text === "关闭", "close label")
                    root.check(root.find(notice, "noticeConfirmButton").text === "查看更新", "view label")
                    root.capture("startup")
                } else if (root.stage === 2) {
                    UiInput.click(root.find(notice, "noticeDismissButton"))
                } else if (root.stage === 3) {
                    root.check(!notice, "close did not dismiss")
                    Updates.check()
                } else if (root.stage === 4) {
                    if (Updates.checking) return
                    root.check(!notice && !root.pendingUpdateNotice, "same version reminded again")
                    root.check(Updates.updateAvailable, "dismissal removed About badge state")
                    loader.item.pageEvent("Start.", { "object": "about" })
                } else if (root.stage === 5) {
                    if (loader.sourceComponent !== Constants.pageOnAbout) return
                    loader.item.revealInformation()
                } else if (root.stage === 6) {
                    var row = root.find(loader.item, "aboutSoftwareVersion")
                    var badge = root.find(row, "aboutUpdateBadge")
                    root.check(badge.visible, "badge missing after dismissal")
                    root.versionRowHeight = row.height
                    root.check(badge.x + badge.width <= row.width + 1, "badge overflows version row")
                    root.capture("about-dark")
                } else if (root.stage === 7) {
                    Colors.applyColorScheme("parchment")
                } else if (root.stage === 8) {
                    root.capture("about-light")
                    UiInput.click(root.find(root.find(loader.item, "aboutSoftwareVersion"), "aboutUpdateBadge"))
                } else if (root.stage === 9) {
                    root.check(notice && notice.title === "发现新版本 v0.2.0", "badge did not reopen same notice")
                    UiInput.click(root.find(notice, "noticeConfirmButton"))
                } else if (root.stage === 10) {
                    root.check(!notice, "view update did not close dialog")
                    root.check(UpdateFixture.openedCount() === 1, "browser action not invoked")
                    root.check(UpdateFixture.lastOpenedUrl() === "https://github.com/XCzongzi/xcshop/releases/tag/v0.2.0", "wrong release URL")
                    UpdateFixture.setVersion("0.3.0")
                    Updates.check()
                } else if (root.stage === 11) {
                    if (!notice || !notice.opened) return
                    root.check(notice.title === "发现新版本 v0.3.0", "changed version did not remind")
                    UiInput.click(root.find(notice, "noticeDismissButton"))
                } else if (root.stage === 12) {
                    UpdateFixture.setVersion("0.1.0")
                    Updates.check()
                } else if (root.stage === 13) {
                    if (Updates.checking) return
                    var versionRow = root.find(loader.item, "aboutSoftwareVersion")
                    root.check(!Updates.updateAvailable, "current release marked newer")
                    root.check(!root.find(versionRow, "aboutUpdateBadge").visible, "badge visible without update")
                    root.check(versionRow.height === root.versionRowHeight, "version row height changed")
                    console.log("UPDATE_UI_SMOKE_PASSED")
                    stop()
                    Qt.quit()
                }
                root.stage++
            } catch (error) {
                console.error("UPDATE_UI_SMOKE_FAILED", error)
                stop()
                Qt.exit(1)
            }
        }
    }
}
