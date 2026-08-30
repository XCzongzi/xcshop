pragma Singleton
import QtQuick

QtObject{

    // 基础信息
    readonly property int margins: 32
    readonly property int window_radius: 8
    readonly property int titleBarHeight: 36

    // url
    readonly property string url_templates: "https://xczongzi.github.io/AppOnlineData-xcshop/templates.json"
    readonly property string url_templatesPer: "https://xczongzi.github.io/AppOnlineData-xcshop/templates/"
    readonly property string url_itemMappings: "https://raw.githubusercontent.com/Plagiatus/ForeverIds/main/items/items.min.json"
    readonly property string url_itemMappingTags: "https://api.github.com/repos/Plagiatus/ForeverIds/tags?per_page=1"


    // 页面
    readonly property Component pageWithEmpty: Qt.createComponent("pages/PageWithEmpty.qml")

    readonly property Component pageOnStart: Qt.createComponent("pages/PageOnStart.qml")
    readonly property Component pageOnCreating: Qt.createComponent("pages/PageOnCreating.qml")
    readonly property Component pageOnOpening: Qt.createComponent("pages/PageOnOpening.qml")
    readonly property Component pageOnTotal: Qt.createComponent("pages/PageOnTotal.qml")
    readonly property Component pageOnUI: Qt.createComponent("pages/PageOnUI.qml")
    readonly property Component pageOnItem: Qt.createComponent("pages/PageOnItem.qml")
    readonly property Component pageOnCost: Qt.createComponent("pages/PageOnCost.qml")
    readonly property Component pageOnDisplay: Qt.createComponent("pages/PageOnDisplay.qml")
    readonly property Component pageOnSettings: Qt.createComponent("pages/PageOnSettings.qml")
    readonly property Component pageOnAbout: Qt.createComponent("pages/PageOnAbout.qml")
    // 弹窗组件由 Main.qml 的 popup Loader 统一创建和释放。
    readonly property Component popupNotice: Qt.createComponent("components/popup/PopupNotice.qml")
    readonly property Component popupMappingHistory: Qt.createComponent("components/popup/PopupMappingHistory.qml")
    readonly property Component popupJsonTextEditor: Qt.createComponent("components/popup/PopupJsonTextEditor.qml")
    

    // 数据
    //存储容器中，槽位的相对位置(x,y)
    readonly property var containerCount: [27,54,9,5,5,3]
    readonly property var containerSlot:[
        [   //0号，普通箱子
            [8,18],[26,18],[44,18],[62,18],[80,18],[98,18],[116,18],[134,18],[152,18],
            [8,36],[26,36],[44,36],[62,36],[80,36],[98,36],[116,36],[134,36],[152,36],
            [8,54],[26,54],[44,54],[62,54],[80,54],[98,54],[116,54],[134,54],[152,54],
        ],
    ]
    
}
