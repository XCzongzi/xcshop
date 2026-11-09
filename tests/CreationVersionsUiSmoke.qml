pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop

Window {
    id: root
    width: 1100; height: 1000; visible: true
    property var page: null
    property var popupRequest: null
    property int popupCount: 0
    property string kitRoot: SMOKE_DIR + "/kits"
    readonly property string alpha: "89755dae-f798-440d-b3a9-342ee8a9070f"
    readonly property string fixed: "89755dae-f798-440d-b3a9-342ee8a9070a"
    XCFile { id: file }
    PopupLoader { id: popup; anchors.fill: parent; z: 100 }
    Component { id: creating; PageOnCreating { fullScreen: false } }
    Component { id: projectSettings; PopupProjectSettings {} }
    Component { id: total; PageOnTotal {} }

    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (var i = 0; i < item.children.length; ++i) {
            var found = find(item.children[i], name)
            if (found) return found
        }
        return null
    }
    function templateFile(name, id, versions) {
        check(file.writeAtomic(kitRoot + "/templates/" + name + ".xcshopT",
              id + "\n0\n" + versions + "\n../blueprints/main.xcshoper\n../materials/alpha\n[\"测试\"]\n"), "write template")
    }
    function closeNotice(confirm) {
        popup.open(popupRequest.component, popupRequest.properties, popupRequest.callback)
        UiInput.settle(60)
        check(popup.item && popup.item.doubleButton, "confirmation must have two actions")
        find(popup.item, confirm ? "noticeConfirmButton" : "noticeDismissButton").clicked()
        UiInput.settle(100)
    }

    Component.onCompleted: {
        Global.animationSpeed = 20
        Global.settingsPath = SMOKE_DIR + "/settings.json"
        file.folder(kitRoot + "/templates")
        file.folder(kitRoot + "/blueprints")
        file.folder(kitRoot + "/materials/alpha")
        check(file.writeAtomic(kitRoot + "/blueprints/main.xcshoper", "build\n"), "write blueprint")
        check(file.writeAtomic(kitRoot + "/materials/alpha/main.xcontent", "test\n"), "write material")
        templateFile("alpha", alpha, '"1.12.2","1.13"...')
        templateFile("fixed", fixed, '"1.13"')
        BuildKits.kitsPath = kitRoot
        BuildKits.preferredTemplateId = alpha
    }

    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            stop()
            try {
                check(GameVersions.versions.length >= 51, "read shipped local version mapping")
                root.page = creating.createObject(root.contentItem, {width: root.width, height: root.height})
                check(root.page, creating.errorString())
                root.page.pageEvent.connect(function(kind, parameters) {
                    if (kind === "Popup.show") { root.popupRequest = parameters; ++root.popupCount }
                })
                var page = root.page
                check(page.versionOptions.map(function(v) { return v.id }).join(",") === ["1.12.2"].concat(GameVersions.versions.map(function(id) { return id })).join(","),
                      "only local mapping versions appended, in numeric order")
                check(!MinecraftAssetImporter.loadingVersions && MinecraftAssetImporter.versions.length === 0,
                      "opening creation never requests the online item catalog")
                check(page.currentVersion === "1.13" && !page.selectedVersionExtended, "default explicit version")
                page.projectNameValue = "supported"
                page.namespaceValue = "test"
                page.storagePathValue = SMOKE_DIR + "/projects"
                page.generatePathValue = SMOKE_DIR + "/generated"
                check(page.canCreate, "supported version can create")
                UiInput.settle(50)
                var explicitButton = root.find(page, "creationVersion_1.13")
                var extendedButton = root.find(page, "creationVersion_1.13.1")
                check(explicitButton && extendedButton && extendedButton.textColor.a < explicitButton.textColor.a,
                      "extended version has lighter text")

                var versionSettings = projectSettings.createObject(root.contentItem, {
                    projectData: {name: "settings-test", namespace: "test", generatePath: SMOKE_DIR + "/generated",
                                  templateId: root.alpha, dataVersion: 0, version: "27.1"},
                    templateOptions: BuildKits.options(0)})
                versionSettings.open()
                var versionChoice = find(versionSettings, "projectVersionChoice")
                check(versionChoice.options.map(function(option) { return option.value }).join(",")
                      === page.versionOptions.map(function(option) { return option.id }).join(","),
                      "settings list matches every creation option, including extended releases")
                check(versionChoice.options.every(function(option) { return option.value !== "27.1" }),
                      "unlisted current version is not added to settings options")
                versionSettings.submit()
                check(!versionSettings.result && versionSettings.validationMessage.length > 0,
                      "settings reject a version outside the shared list")
                find(versionSettings, "projectTemplateChoice").valueActivated(root.fixed)
                page.selectTemplate(page.templateItems.findIndex(function(t) { return t.id === root.fixed }))
                check(versionChoice.options.length === 1 && versionChoice.options[0].value === page.currentVersion,
                      "changing template refreshes settings options without newer-version input")
                find(versionSettings, "projectTemplateChoice").valueActivated(root.alpha)
                page.selectTemplate(page.templateItems.findIndex(function(t) { return t.id === root.alpha }))
                check(versionChoice.options.length === page.versionOptions.length, "version options stay bound after template changes")
                versionChoice.valueActivated("1.13.1")
                versionSettings.submit()
                var versionWarning = find(versionSettings, "projectVersionWarning")
                check(versionWarning.visible && !versionSettings.result, "extended version waits for confirmation")
                check(versionWarning.content.indexOf("该版本并未明确受到模板的支持") === 0,
                      "settings show the same compatibility warning as creation")
                versionSettings.submit()
                find(versionWarning, "noticeDismissButton").clicked()
                UiInput.settle(80)
                check(!versionSettings.result && !versionWarning.visible && versionChoice.value === "1.13.1",
                      "cancel keeps project settings open with the selected version")
                versionSettings.submit()
                find(versionWarning, "noticeConfirmButton").clicked()
                UiInput.settle(80)
                check(versionSettings.result && versionSettings.result.version === "1.13.1",
                      "settings save an extended version only after confirmation")
                versionSettings.destroy()

                var unchangedSettings = projectSettings.createObject(root.contentItem, {
                    projectData: {name: "settings-test", namespace: "test", generatePath: SMOKE_DIR + "/generated",
                                  templateId: root.alpha, dataVersion: 0, version: "1.13.1",
                                  dataPackVersion: {major: 4, minor: 0}},
                    templateOptions: BuildKits.options(0)})
                unchangedSettings.open()
                unchangedSettings.submit()
                check(unchangedSettings.result && !find(unchangedSettings, "projectVersionWarning").visible,
                      "saving an unchanged extended version does not repeat the warning")
                unchangedSettings.destroy()
                UiInput.settle(50)
                extendedButton = root.find(page, "creationVersion_1.13.1")
                check(extendedButton, "creation version buttons refreshed after changing templates")

                page.createProject()
                check(page.projectCreationSucceeded && root.popupCount === 0, "explicit version creates immediately")
                var explicitProject = JSON.parse(file.read(SMOKE_DIR + "/projects/supported/xcshop.json"))
                check(explicitProject.dataPackVersion.major === 4 && explicitProject.dataPackVersion.minor === 0,
                      "creation stores mapped data pack version")

                page.projectCreationSucceeded = false
                page.projectNameValue = "extended"
                extendedButton.clicked()
                check(page.currentVersion === "1.13.1" && page.selectedVersionExtended, "select extended version")
                page.createProject()
                check(root.popupRequest.properties.content === "该版本并未明确受到模板的支持，因此生成的数据包在该版本可能无法正常工作。但也未被证实必然会失效。\n是否确认接着创建？", "exact compatibility message")
                check(!file.exists(SMOKE_DIR + "/projects/extended"), "no files before confirmation")
                page.createProject()
                check(root.popupCount === 1, "ignore repeated clicks while confirming")
                root.closeNotice(false)
                check(!page.projectCreationSucceeded && !page.creationConfirmationPending
                      && !file.exists(SMOKE_DIR + "/projects/extended"), "cancel creates nothing")
                page.createProject()
                root.closeNotice(true)
                check(page.projectCreationSucceeded, "confirm creates project")
                check(JSON.parse(file.read(SMOKE_DIR + "/projects/extended/xcshop.json")).version === "1.13.1", "save selected release id")
                check(JSON.parse(file.read(SMOKE_DIR + "/projects/extended/xcshop.json")).dataPackVersion.major === 4,
                      "extended release also stores mapped pack version")

                page.selectTemplate(page.templateItems.findIndex(function(t) { return t.id === root.fixed }))
                check(page.versionOptions.length === 1 && !page.selectedVersionExtended, "no ellipsis means no expansion")
                page.currentVersion = "1.13.2"
                check(!page.canCreate, "unlisted version rejected")

                // Use real settings and overview saving, without running the builder.
                templateFile("alpha", alpha, '"1.13","1.21.11","26.1.2","26.3","27.1"...')
                BuildKits.refresh()
                page.selectTemplate(page.templateItems.findIndex(function(t) { return t.id === root.alpha }))
                page.projectCreationSucceeded = false
                page.projectNameValue = "future"
                page.createProject()
                var future = JSON.parse(file.read(SMOKE_DIR + "/projects/future/xcshop.json"))
                check(future.version === "27.1" && future.dataPackVersion.major === 121
                      && future.dataPackVersion.minor === 0, "future project creation uses newest mapped pair")
                Global.project_location = SMOKE_DIR + "/projects/supported"
                var overview = total.createObject(root.contentItem, {width: root.width, height: root.height})
                UiInput.settle(80)
                check(overview && overview.manifestLoaded, "load created project")
                var targets = [{id:"26.1.2",major:101,minor:1}, {id:"1.21.11",major:94,minor:1},
                               {id:"27.1",major:121,minor:0}]
                for (var target of targets) {
                    var settings = projectSettings.createObject(root.contentItem, {
                        projectData: overview.projectData, projectLocation: Global.project_location,
                        templateOptions: BuildKits.options(0)})
                    settings.open()
                    find(settings, "projectVersionChoice").value = target.id
                    settings.submit()
                    check(settings.result && settings.result.version === target.id,
                          "settings accept version: " + settings.validationMessage)
                    check(overview.saveProjectChanges(settings.result), "save settings result")
                    var saved = JSON.parse(file.read(Global.project_location + "/xcshop.json"))
                    check(saved.version === target.id && saved.dataPackVersion.major === target.major
                          && saved.dataPackVersion.minor === target.minor, "version and data pack pair saved atomically")
                    settings.destroy()
                }
                check(overview.saveProjectChanges({name:"renamed",dataPackVersion:{major:900,minor:12}}), "save stored pair")
                check(overview.saveProjectChanges({name:"renamed-again"}), "save unrelated field")
                check(overview.projectData.dataPackVersion.major === 900
                      && overview.projectData.dataPackVersion.minor === 12, "unchanged game version preserves stored pair")
                check(overview.saveProjectChanges({version:"26.3"}), "version change through save path")
                check(overview.projectData.dataPackVersion.major === 121
                      && overview.projectData.dataPackVersion.minor === 0, "version change recomputes stored pair")
                check(overview.saveProjectChanges({dataPackVersion:null}), "fill missing pair without changing game version")
                check(overview.projectData.dataPackVersion.major === 121, "old project receives mapped version")
                var cancelled = projectSettings.createObject(root.contentItem, {
                    projectData: overview.projectData, templateOptions: BuildKits.options(0)})
                cancelled.open()
                find(cancelled, "projectVersionChoice").value = "1.21.11"
                cancelled.close(null)
                check(JSON.parse(file.read(Global.project_location + "/xcshop.json")).version === "26.3", "cancel preserves manifest")
                cancelled.destroy()
                overview.destroy()
                console.log("CREATION_VERSIONS_UI_SMOKE_PASSED")
                Qt.quit()
            } catch (error) {
                console.error("CREATION_VERSIONS_UI_SMOKE_FAILED", error)
                Qt.exit(1)
            }
        }
    }
}
