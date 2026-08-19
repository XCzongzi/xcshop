pragma Singleton
import QtQuick

QtObject{

    readonly property int margins: 32
    readonly property int window_radius: 8
    readonly property int titleBarHeight: 36

    readonly property string url_templates: "https://xczongzi.github.io/AppOnlineData-xcshop/templates.json"
    readonly property string url_templatesPer: "https://xczongzi.github.io/AppOnlineData-xcshop/templates/"
    readonly property string url_itemMappings: "https://raw.githubusercontent.com/Plagiatus/ForeverIds/main/items/items.min.json"
    readonly property string url_itemMappingTags: "https://api.github.com/repos/Plagiatus/ForeverIds/tags?per_page=1"



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
    readonly property Component batchRename: Qt.createComponent("pages/BatchRename.qml")

    // 弹窗组件由 Main.qml 的 popup Loader 统一创建和释放。
    readonly property Component popupNotice: Qt.createComponent("components/popup/PopupNotice.qml")
    
}
