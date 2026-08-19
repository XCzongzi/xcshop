pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import xcshop 1.0



XCWindow {
    id: mainWindow

    Component.onCompleted: {
        Global.loadSettings()
        //连接信号
        SignalBus.sendToMain.connect(root.signalReceive)
        
        typeBar.opacity = false
        typeBar.isEnabled = false
        //mainWindow.showFilePage = true //临时的
        Global.mainWindow_background = mainWindow.background
    }
    // ConsoleWindow{  //控制台，临时的
    //     onInputed:function(command) {
    //         if(command.c1 === "pageSwitch"){
    //             switch(command.c2){
    //                 case "UI":
    //                     pageLoader.pageSwitch(Constants.pageOnUI)
    //                 break;case "Item":
    //                     pageLoader.pageSwitch(Constants.pageOnItem)
    //                 break;case "Cost":
    //                     pageLoader.pageSwitch(Constants.pageOnCost)
    //                 break;case "Display":
    //                     pageLoader.pageSwitch(Constants.pageOnDisplay)
    //                 break;case "Total":
    //                     pageLoader.pageSwitch(Constants.pageOnTotal)
    //                 break;case "Start":
    //                     pageLoader.pageSwitch(Constants.pageOnStart)
    //                 break;case "Empty":
    //                     pageLoader.pageSwitch(Constants.pageWithEmpty)
    //                 break;case "Open":
    //                     pageLoader.pageSwitch(Constants.pageOnOpening)
    //                 break;case "Create":
    //                     pageLoader.pageSwitch(Constants.pageOnCreating)
    //                 break
    //             }
    //         }
    //     }
    // }

    // MultiEffect {
    //     id: backBlur
    //     anchors.fill: root
    //     source: null
    //     blurEnabled: true
    //     blur: 1.0
    //     //blurMax: 32
    //     function enable(){
    //         source = root
    //         root.visible = false
    //     }
    //     function disable(){
    //         source = null
    //         root.visible = true
    //     }
    // }
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

        function showNotice(title, content, callback) {
            popup.open(Constants.popupNotice, {
                "title": title,
                "content": content
            }, callback)
        }
        
        TypeBar{
            id: typeBar
            z: extraMenuOpened? 100 : 98    //跟RelayBar抢占更高层
            onTypeBtnClicked: typeName=>root.typeSwitch(typeName,false)
            bottomLeftRadius: mainWindow.visibility === Window.Maximized? 0 : Constants.window_radius
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
            if(!after)elementExplorer.floderReset()
            if(typeName === "Total"){
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
                elementExplorer.started = true
                root.typeSwitch(element.type, false)
                return
            }

            elementExplorer.openElementFolder(element.folder)
            if (!sameFile)
                SignalBus.sendToMain("switched_file", {})
        }

        ElementExplorer{
            id: elementExplorer
            z:97
            visible: root.workspaceChromeVisible
            barWidth: 150
            onStartedChanged:{
                Console.output("ElementExplorer started to be changed to " + elementExplorer.started)
                if(Global.project_location !="")root.typeSwitch(Global.current_element,true)
            }
        }

        ElementRelayBar {
            id: elementRelayBar
            z: 99
            x: root.pageX
            y: root.height - height
            width: Math.max(0, root.width - x)
            workspaceActive: root.workspaceChromeVisible
            maxPanelHeight: Math.max(minPanelHeight, root.height - fileControlsBar.height - 120)
            onInvalidElement: function(filePath) {
                root.showNotice("元素已失效", "找不到对应元素文件，已从中转区移除：\n" + filePath)
            }
            onElementActivated: function(filePath) {
                root.openElementFromRelay(filePath)
            }
        }
        RelaySelectionMask{}

        PopupLoader {
            id: popup
            anchors.fill: parent
        }


        // ------------------------主窗口区-------------------


        // Pages_FileList{
        //     id:fileListBar
        //     visible: pageLoader.item.workspace
        //     x: root.pageX + 8
        // }
        FileControls{
            id:fileControlsBar
            visible: root.workspaceChromeVisible
            x: root.pageX
        }


        readonly property bool workspaceChromeVisible: typeBar.isEnabled && Global.project_location.length > 0
        property int pageX: elementExplorer.x + elementExplorer.width

        Loader{
            id:pageLoader
            
            x: Math.max(root.pageX,65)
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
                duration: 250
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
                opcAnim.start()

                if(pageLoader.page === Constants.pageOnStart){
                    mainWindow.titleBarColorFilling = false
                }else{
                    mainWindow.titleBarColorFilling = true
                }
            }


            Connections{    //信号处理
                target: pageLoader.item
                function onPageEvent(signalType,parameters){
                    switch(signalType){
                        case "Start.":
                            switch(parameters.object){
                                case "create": pageLoader.pageSwitch(Constants.pageOnCreating)
                                break;case "projectOpened":
                                    typeBar.enable(false)
                                    root.typeSwitch("Total", true)
                                break;case "settings":
                                    root.settingsFromWorkspace = false
                                    pageLoader.pageSwitch(Constants.pageOnSettings)
                                break;case "about":
                                    root.settingsFromWorkspace = false
                                    pageLoader.pageSwitch(Constants.pageOnAbout)
                            }
                        break

                        case "NoticeBar.show":
                            root.showNotice(parameters[0], parameters[1], function(result) {
                                if (pageLoader.item && typeof pageLoader.item.executeFromMain === "function")
                                    pageLoader.item.executeFromMain("notice", result)
                            })
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
