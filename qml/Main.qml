pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop 1.0



XCWindow {
    id: mainWindow
    visible: false
    readonly property string windowStatePath: APP_DIRPATH + "/window-state.ini"
    property bool closeAfterBuild: false
    property bool closeQuestionShown: false
    property bool pendingUpdateNotice: false

    Connections {
        target: Qt.application
        function onAboutToQuit() { mainWindow.saveWindowState(mainWindow.windowStatePath) }
    }

    Connections {
        target: Updates
        function onStartupUpdateAvailable() { mainWindow.pendingUpdateNotice = true }
    }

    onClosing: function(event) {
        if (!Builder.running) return
        event.accepted = false
        if (closeQuestionShown || closeAfterBuild) return
        closeQuestionShown = true
        root.showPopup(Constants.popupNotice, {
            "title": "构建仍在运行",
            "content": "是否停止构建并退出编辑器？\n如果已经进入写入阶段，请在下次使用前重新构建确认输出。",
            "doubleButton": true
        }, function(result) {
            mainWindow.closeQuestionShown = false
            if (result !== 1) return
            if (!Builder.running) { Qt.quit(); return }
            mainWindow.closeAfterBuild = true
            Builder.cancel()
        })
    }
    Connections {
        target: Builder
        function onCompleted(success) { if (mainWindow.closeAfterBuild) Qt.quit() }
    }

    Component.onCompleted: {
        restoreWindowState(windowStatePath)
        if (expanded) showMaximized()
        else showNormal()
        Global.loadSettings()
        //连接信号
        SignalBus.sendToMain.connect(root.signalReceive)
        
        typeBar.opacity = false
        typeBar.isEnabled = false
        Global.mainWindow_background = mainWindow.background
        Global.mainWindow_backdrop = mainWindow.backdrop
        Global.mainWindow_popupBackdrop = popupBlurSource
        Global.mainWindow_popupHost = root
    }
    WindowSurface{
        id: root
        mainWindow: mainWindow
        onWidthChanged: Global.window_width = root.width
        onHeightChanged: Global.window_height = root.height
        ignoreTitleBar: pageLoader.sourceComponent === Constants.pageOnStart
                        || pageLoader.sourceComponent === Constants.pageOnAbout
        
        property bool settingsFromWorkspace: false

        // 所有模态弹窗均从这里进入。弹窗组件只需提供 close(result) 函数并发出 closed(result) 信号。
        function showPopup(component, properties, callback) {
            popup.open(component, properties, callback)
        }

        function showUpdateDialog() {
            if (!Updates.updateAvailable || popup.active) return
            mainWindow.pendingUpdateNotice = false
            var version = Updates.latestVersion
            var destination = Updates.releaseUrl
            root.showPopup(Constants.popupNotice, {
                "objectName": "updateNotice",
                "title": "发现新版本 v" + version,
                "content": "当前版本：v" + Qt.application.version + "\n最新版本：v" + version
                           + "\n\n" + (Updates.releaseNotes || "查看发布页面，了解本次更新内容。")
                           + "\n\n关闭后，此版本将不再自动提醒；仍可在关于页查看。",
                "dialogWidth": 560,
                "dialogHeight": 420,
                "doubleButton": true,
                "cancelText": "关闭",
                "confirmText": "查看更新"
            }, function(result) {
                if (result === 0) {
                    Updates.dismissVersion(version)
                } else if (result === 1 && !Qt.openUrlExternally(destination)) {
                    root.showPopup(Constants.popupNotice, {
                        "title": "无法打开浏览器",
                        "content": "请手动访问：\n" + destination
                    })
                }
            })
        }

        // Do not replace another dialog or interrupt a running build.
        Timer {
            interval: 250
            repeat: true
            running: mainWindow.pendingUpdateNotice
            onTriggered: {
                if (!popup.active && !Builder.running && !mainWindow.closeQuestionShown)
                    root.showUpdateDialog()
            }
        }

        // 独立的背景与页面内容层，不包含弹窗，供磨砂面板安全取样。
        Item {
            id: popupBlurSource
            anchors.fill: parent
            ShaderEffectSource {
                // Keep the backdrop viewport fixed to the whole window surface.
                // Only page content moves down when the titlebar is reserved.
                x: mainWindow.margins - root.x
                y: mainWindow.margins - root.y
                width: mainWindow.surfaceWidth
                height: mainWindow.surfaceHeight
                visible: GraphicsInfo.api !== GraphicsInfo.Software
                sourceItem: mainWindow.backdrop
                sourceRect: Qt.rect(0, 0, width, height)
            }
            Item {
                id: workspaceForeground
                objectName: "workspaceForeground"
                anchors.fill: parent
                opacity: workspaceEntrance.contentOpacity
            }
        }
        
        TypeBar{
            id: typeBar
            parent: workspaceForeground
            z: extraMenuOpened? 100 : 98    //跟RelayBar抢占更高层
            onTypeBtnClicked: typeName=>root.typeSwitch(typeName,false)
            bottomLeftRadius: mainWindow.frameRadius
            onExtraButton_clicked:function(type) {
                root.settingsFromWorkspace = true
                elementExplorer.barHide(false)
                typeBar.disable(true)
                switch (type){
                    case "about":
                        pageLoader.pageSwitch(Constants.pageOnAbout)
                    break;case "settings":
                        pageLoader.pageSwitch(Constants.pageOnSettings)
                }
            }
        }
        function typeSwitch(typeName,after) {   //为了方便后续调用，就把type原本的槽函数单独分离了出来，after用于区分是否后期调用
            Global.current_element = typeName   //after的作用是取消动画
            // 中转区可以直接调用 typeSwitch；同步类型栏的视觉选中态，不能只依赖按钮点击。
            switch(typeName){
                case "Global": typeBar.currentType = 0; break
                case "UI": typeBar.currentType = 1; break
                case "Item": typeBar.currentType = 2; break
                case "Cost": typeBar.currentType = 3; break
                case "Display": typeBar.currentType = 4; break
            }
            if(!after)elementExplorer.floderReset()
            if(typeName === "Global"){
                elementExplorer.barHide()
                pageLoader.pageSwitch(Constants.pageOnTotal)
            }else{
                elementExplorer.barShow()
                switch(typeName){
                    case "UI":
                        pageLoader.pageSwitch(elementExplorer.started? Constants.pageOnUI : Constants.pageWithEmpty)
                    break;case "Item":
                        pageLoader.pageSwitch(elementExplorer.started? Constants.pageOnItem : Constants.pageWithEmpty)
                    break;case "Cost":
                        pageLoader.pageSwitch(elementExplorer.started? Constants.pageOnCost : Constants.pageWithEmpty)
                    break;case "Display":
                        pageLoader.pageSwitch(elementExplorer.started? Constants.pageOnDisplay : Constants.pageWithEmpty)
                    break
                }
            }
        }
        function openElementFromRelay(filePath) {
            var element = Global.parseElementPath(filePath)
            if (!element)
                return

            var typeChanged = Global.current_element !== element.type
            var sameFile = Global.normalizeElementPath(Global.get_filePath()) === element.path

            Global.current_element = element.type
            Global.set_file(element.folder, element.name)
            SignalBus.elementOpened(element.type, element.path, element.name)

            if (typeChanged) {
                // floderReset 的计时器会读取此值，避免切换类型时回到根目录。
                elementExplorer.pendingFolder = element.folder
                root.typeSwitch(element.type, false)
                return
            }

            elementExplorer.openElementFolder(element.folder)
            if (!sameFile)
                SignalBus.sendToMain("switched_file", {})
        }

        ElementExplorer{
            id: elementExplorer
            parent: workspaceForeground
            z:97
            visible: root.workspaceChromeVisible
            barWidth: Global.elementExplorerWidth
            onStartedChanged:{
                // 打开或删除当前类型的文件都会改变 started。两种情况都
                // 必须刷新页面，才能在删除后切回 PageWithEmpty。
                if (Global.project_location != "")
                    root.typeSwitch(Global.current_element, true)
            }
        }

        ElementRelayBar {
            id: elementRelayBar
            parent: workspaceForeground
            z: 99
            x: root.pageX
            y: root.height - height
            width: Math.max(0, root.width - x)
            workspaceActive: root.workspaceChromeVisible
            maxPanelHeight: Math.max(minPanelHeight, root.height - fileControlsBar.height - 120)
            onInvalidElement: function(filePath) {
                root.showPopup(Constants.popupNotice, {
                    "title": "元素已失效",
                    "content": "找不到对应元素文件，已从中转区移除：\n" + filePath
                })
            }
            onElementActivated: function(filePath) {
                root.openElementFromRelay(filePath)
            }
        }
        RelaySelectionMask{
            parent: workspaceForeground
        }

        PopupLoader {
            id: popup
            anchors.fill: parent
        }

        //右键菜单
        ContextMenu {
            id: globalContextMenu
            z: 1001
            onClosed: SignalBus.contextMenuClosed()
        }

        Connections {
            target: SignalBus

            function onElementOpenRequested(filePath) {
                root.openElementFromRelay(filePath)
            }

            function onContextMenuRequested(target, x, y, items, contentComponent) {
                globalContextMenu.menuItems = items || []
                globalContextMenu.contentComponent = contentComponent || null
                globalContextMenu.openFor(target, x, y)
            }

            function onContextMenuCloseRequested() {
                globalContextMenu.close()
            }
        }


        // ------------------------主窗口区-------------------


        // Pages_FileList{
        //     id:fileListBar
        //     visible: pageLoader.item.workspace
        //     x: root.pageX + 8
        // }
        FileControls {
            id: fileControlsBar
            parent: workspaceForeground
            visible: root.workspaceChromeVisible
            x: root.pageX
            onLocateCurrentElementRequested: elementExplorer.locateCurrentElement()
            onBuildDetailsRequested: root.typeSwitch("Global", true)
        }

        readonly property bool workspaceChromeVisible: typeBar.isEnabled && Global.project_location.length > 0
        property int pageX: elementExplorer.x + elementExplorer.width

        WorkspaceEntrance {
            id: workspaceEntrance
            property Component destinationPage: null
            showAboutBrand: destinationPage === Constants.pageOnAbout
            parent: mainWindow.contentItem
            x: mainWindow.margins
            y: mainWindow.margins
            width: mainWindow.surfaceWidth
            height: mainWindow.surfaceHeight
            z: 98
            onCovered: {
                opcAnim.stop()
                if (destinationPage) {
                    mainWindow.titleBarColorFilling = destinationPage === Constants.pageOnSettings
                    pageLoader.sourceComponent = destinationPage
                    return
                }
                if (closing) {
                    // Unload the workspace before clearing its backing state.
                    pageLoader.sourceComponent = null
                    typeBar.disable(false)
                    elementExplorer.barHide(false)
                    elementExplorer.pendingFolder = ""
                    elementRelayBar.endSelection()
                    root.settingsFromWorkspace = false
                    Global.project_location = ""
                    Global.version = ""
                    Global.current_fileLocation = ["", "", "", "", ""]
                    Global.current_fileName = ["", "", "", "", ""]
                    Global.uiCanvasViews = ({})
                    Global.current_element = "Global"
                    typeBar.currentType = 0
                    mainWindow.titleBarColorFilling = false
                    pageLoader.sourceComponent = Constants.pageOnStart
                    return
                }
                Global.current_element = "Global"
                typeBar.currentType = 0
                typeBar.enable(false)
                elementExplorer.barHide(false)
                mainWindow.titleBarColorFilling = true
                pageLoader.sourceComponent = Constants.pageOnTotal
            }
            onFinished: {
                destinationPage = null
                typeBar.freeze = false
                freeze.visible = false
                if (pageLoader.item) pageLoader.item.forceActiveFocus()
            }
        }

        Loader{
            id:pageLoader
            objectName: "mainPageLoader"
            parent: workspaceForeground
            
            readonly property bool aboutPage: sourceComponent === Constants.pageOnAbout
            x: aboutPage ? 0 : Math.max(root.pageX, Constants.typeBarWidth)
            y: root.workspaceChromeVisible ? fileControlsBar.height : 0
            height: Math.max(0, root.height - y - elementRelayBar.height)
            width: aboutPage ? root.width : root.workspaceChromeVisible ? root.width - x : root.width - x + 65
            z: 96
            transform: Translate { y: 16 * (1 - workspaceEntrance.reveal) }
            sourceComponent: Constants.pageOnStart
            onItemChanged: {
                if (item)
                    item.mainWindow = mainWindow
            }
            MouseArea{
                id: freeze
                visible: false
                anchors.fill: parent
                hoverEnabled: true
                z: 999
            }
            property var page   //销毁动画
            NumberAnimation{
                id: opcAnim
                target: pageLoader.item
                property: "opacity"
                duration: 250 / Global.animationSpeed
                to: 0
                easing.type: Easing.OutQuad
                onFinished: {
                    pageLoader.sourceComponent = pageLoader.page
                    typeBar.freeze = false
                    freeze.visible = false
                }
            }
            function pageSwitch(page_){
                if (workspaceEntrance.busy) return
                if ((pageLoader.sourceComponent === Constants.pageOnStart && page_ === Constants.pageOnSettings)
                        || (page_ === Constants.pageOnAbout && pageLoader.sourceComponent !== page_)) {
                    workspaceEntrance.destinationPage = page_
                    workspaceEntrance.start(false, "")
                    return
                }
                if(pageLoader.sourceComponent === page_)return    //防止重复切换
                typeBar.freeze = true
                freeze.visible = true
                pageLoader.page = page_

                if(pageLoader.page === Constants.pageOnStart || pageLoader.page === Constants.pageOnAbout){
                    mainWindow.titleBarColorFilling = false
                }else{
                    mainWindow.titleBarColorFilling = true
                }

                if(pageLoader.page === Constants.pageOnUI       //切换前检测销毁动画，仅在工作区时跳过播放
                || pageLoader.page === Constants.pageOnItem
                || pageLoader.page === Constants.pageOnCost
                || pageLoader.page === Constants.pageOnDisplay){
                    opcAnim.onFinished()
                }else{
                    opcAnim.start()
                }
            }


            Connections{    //信号处理
                target: pageLoader.item
                function onPageEvent(signalType,parameters){
                    switch(signalType){
                        case "Start.":
                            switch(parameters.object){
                                case "projectOpened":
                                    workspaceEntrance.start(false, parameters.name)
                                break;case "settings":
                                    root.settingsFromWorkspace = false
                                    pageLoader.pageSwitch(Constants.pageOnSettings)
                                break;case "about":
                                    root.settingsFromWorkspace = false
                                    pageLoader.pageSwitch(Constants.pageOnAbout)
                            }
                        break

                        // 页面可以通过 pageEvent("Popup.show", { component, properties, callback }) 请求任意弹窗。
                        case "Popup.show":
                            root.showPopup(parameters.component, parameters.properties, parameters.callback)
                        break
                        case "Popup.close":
                            popup.close(parameters.result)
                        break
                        case "Updates.show":
                            root.showUpdateDialog()
                        break

                        case "Creating.projectCreated":
                            workspaceEntrance.start(true, parameters.name)
                        break
                        case "Creating.back":
                            pageLoader.pageSwitch(Constants.pageOnStart)
                        break

                        case "Project.close":
                            if (Builder.running || workspaceEntrance.busy) return
                            workspaceEntrance.start(false, String(pageLoader.item.projectData.name || "XCShop"), true)
                        break

                        case "Settings.back":
                            if (root.settingsFromWorkspace) {
                                root.settingsFromWorkspace = false
                                typeBar.enable(false)
                                root.typeSwitch(Global.current_element, true)
                            } else {
                                pageLoader.pageSwitch(Constants.pageOnStart)
                            }
                        break

                        case "About.back":
                            if (root.settingsFromWorkspace) {
                                root.settingsFromWorkspace = false
                                typeBar.enable(false)
                                root.typeSwitch(Global.current_element, true)
                            } else {
                                pageLoader.pageSwitch(Constants.pageOnStart)
                            }
                        break

                        default:

                    }
                }
            }
        }
        function signalReceive(signalType,parameters){
            switch(signalType){
                // 非页面组件可通过 SignalBus 使用同一套弹窗入口。
                case "Popup.show":
                    root.showPopup(parameters.component, parameters.properties, parameters.callback)
                break
                case "Popup.close":
                    popup.close(parameters.result)
                break
                case "switched_file":
                    if(pageLoader.sourceComponent === Constants.pageWithEmpty)return
                    var tempcom = pageLoader.sourceComponent
                    pageLoader.sourceComponent = undefined
                    pageLoader.pageSwitch(tempcom)
                break
            }
        }
    }
}
