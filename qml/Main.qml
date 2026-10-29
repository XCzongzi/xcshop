pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import xcshop 1.0



XCWindow {
    id: mainWindow
    property bool closeAfterBuild: false
    property bool closeQuestionShown: false

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
        Global.loadSettings()
        //连接信号
        SignalBus.sendToMain.connect(root.signalReceive)
        
        typeBar.opacity = false
        typeBar.isEnabled = false
        //mainWindow.showFilePage = true //临时的
        Global.mainWindow_background = mainWindow.background
        Global.mainWindow_backdrop = mainWindow.backdrop
        Global.mainWindow_popupBackdrop = popupBlurSource
    }
    WindowSurface{
        id: root
        mainWindow: mainWindow
        onWidthChanged: Global.window_width = root.width
        onHeightChanged: Global.window_height = root.height
        ignoreTitleBar: pageLoader.sourceComponent === Constants.pageOnStart
        
        property bool settingsFromWorkspace: false

        // 所有模态弹窗均从这里进入。弹窗组件只需提供 close(result) 函数并发出 closed(result) 信号。
        function showPopup(component, properties, callback) {
            popup.open(component, properties, callback)
        }

        // 独立的背景与页面内容层，不包含弹窗，供磨砂面板安全取样。
        Item {
            id: popupBlurSource
            anchors.fill: parent
            ShaderEffectSource {
                anchors.fill: parent
                visible: GraphicsInfo.api !== GraphicsInfo.Software
                sourceItem: mainWindow.backdrop
                sourceRect: {
                    root.x; root.y
                    return popupBlurSource.mapToItem(mainWindow.backdrop, Qt.rect(0, 0, width, height))
                }
            }
        }
        
        TypeBar{
            id: typeBar
            parent: popupBlurSource
            z: extraMenuOpened? 100 : 98    //跟RelayBar抢占更高层
            onTypeBtnClicked: typeName=>root.typeSwitch(typeName,false)
            bottomLeftRadius: mainWindow.expanded ? 0 : Constants.window_radius
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
            parent: popupBlurSource
            z:97
            visible: root.workspaceChromeVisible
            barWidth: Global.elementExplorerWidth
            onStartedChanged:{
                Console.output("ElementExplorer started to be changed to " + elementExplorer.started)
                // 打开或删除当前类型的文件都会改变 started。两种情况都
                // 必须刷新页面，才能在删除后切回 PageWithEmpty。
                if (Global.project_location != "")
                    root.typeSwitch(Global.current_element, true)
            }
        }

        ElementRelayBar {
            id: elementRelayBar
            parent: popupBlurSource
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
            parent: popupBlurSource
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
            parent: popupBlurSource
            visible: root.workspaceChromeVisible
            x: root.pageX
        }

        readonly property bool workspaceChromeVisible: typeBar.isEnabled && Global.project_location.length > 0
        property int pageX: elementExplorer.x + elementExplorer.width

        Loader{
            id:pageLoader
            parent: popupBlurSource
            
            x: Math.max(root.pageX, Constants.typeBarWidth)
            y: root.workspaceChromeVisible ? fileControlsBar.height : 0
            height: Math.max(0, root.height - y - elementRelayBar.height)
            width: root.workspaceChromeVisible ? root.width - x : root.width - x + 65
            z: 96
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
                if(pageLoader.sourceComponent === page_)return    //防止重复切换
                typeBar.freeze = true
                freeze.visible = true
                pageLoader.page = page_

                if(pageLoader.page === Constants.pageOnStart){  //开始界面填充标题栏
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
                                    typeBar.enable(false)
                                    root.typeSwitch("Global", true)
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

                        case "Creating.projectCreated":
                            typeBar.enable(false)
                            pageLoader.sourceComponent = Constants.pageOnTotal //取消销毁动画，以配合页面动画
                        break
                        case "Creating.back":
                            pageLoader.pageSwitch(Constants.pageOnStart)
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
                    Console.output("switched")
                    var tempcom = pageLoader.sourceComponent
                    pageLoader.sourceComponent = undefined
                    pageLoader.pageSwitch(tempcom)
                break
            }
        }
    }
}
