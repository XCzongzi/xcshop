pragma Singleton
import QtQuick

QtObject{

    // 基础信息
    readonly property int margins: 32
    readonly property int window_radius: 8
    readonly property int titleBarHeight: 36
    readonly property int typeBarWidth: 48

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
    readonly property Component popupTextInput: Qt.createComponent("components/popup/PopupTextInput.qml")
    readonly property Component popupProjectSettings: Qt.createComponent("components/popup/PopupProjectSettings.qml")
    readonly property Component popupShopSettings: Qt.createComponent("components/popup/PopupShopSettings.qml")
    readonly property Component popupMappingHistory: Qt.createComponent("components/popup/PopupMappingHistory.qml")
    readonly property Component popupJsonTextEditor: Qt.createComponent("components/popup/PopupJsonTextEditor.qml")
    

    // 数据
    //存储容器中，槽位的相对位置(x,y)
    readonly property var containerCount: [27,54,9,5,5,3]
    readonly property var containerSlot:[
        [//0号，普通箱子
            [8,18],[26,18],[44,18],[62,18],[80,18],[98,18],[116,18],[134,18],[152,18],
            [8,36],[26,36],[44,36],[62,36],[80,36],[98,36],[116,36],[134,36],[152,36],
            [8,54],[26,54],[44,54],[62,54],[80,54],[98,54],[116,54],[134,54],[152,54],
        ],
        [//1号，大型箱子
            [8,18],[26,18],[44,18],[62,18],[80,18],[98,18],[116,18],[134,18],[152,18],
            [8,36],[26,36],[44,36],[62,36],[80,36],[98,36],[116,36],[134,36],[152,36],
            [8,54],[26,54],[44,54],[62,54],[80,54],[98,54],[116,54],[134,54],[152,54],
            [8,72],[26,72],[44,72],[62,72],[80,72],[98,72],[116,72],[134,72],[152,72],
            [8,90],[26,90],[44,90],[62,90],[80,90],[98,90],[116,90],[134,90],[152,90],
            [8,108],[26,108],[44,108],[62,108],[80,108],[98,108],[116,108],[134,108],[152,108],
        ],
        [//2号，发射器
            [62,17],[80,17],[98,17],
            [62,35],[80,35],[98,35],
            [62,53],[80,53],[98,53],
        ],
        [//3号，漏斗
            [44,20],[62,20],[80,20],[98,20],[116,20],
        ],
        [//4号，酿造台
            [56,51],[79,58],[102,51],[79,17],[17,17]
        ],
        [//5号，熔炉
            [56,17],[56,53],[116,35]
        ]
    ]

    // 可作为商店入口的 Minecraft 容器。containerId 与项目格式草案保持一致，
    // layoutId 表示它在编辑器中复用的槽位布局。
    readonly property var shulkerBoxOptions: [
        { "value": "shulker_box", "label": "原色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "white_shulker_box", "label": "白色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "orange_shulker_box", "label": "橙色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "magenta_shulker_box", "label": "品红色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "light_blue_shulker_box", "label": "淡蓝色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "yellow_shulker_box", "label": "黄色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "lime_shulker_box", "label": "黄绿色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "pink_shulker_box", "label": "粉红色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "gray_shulker_box", "label": "灰色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "light_gray_shulker_box", "label": "淡灰色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "cyan_shulker_box", "label": "青色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "purple_shulker_box", "label": "紫色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "blue_shulker_box", "label": "蓝色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "brown_shulker_box", "label": "棕色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "green_shulker_box", "label": "绿色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "red_shulker_box", "label": "红色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" },
        { "value": "black_shulker_box", "label": "黑色潜影盒（27 格）", "layoutId": "generic_9x3", "group": "shulker" }
    ]

    // Keep validation and persistence flat; the picker groups shulkers into a submenu.
    readonly property var shopContainerOptions: [
        { "value": "barrel", "label": "木桶（27 格）", "layoutId": "generic_9x3" },
        { "value": "chest", "label": "箱子（27 格）", "layoutId": "generic_9x3" },
        { "value": "trapped_chest", "label": "陷阱箱（27 格）", "layoutId": "generic_9x3" },
        { "value": "ender_chest", "label": "末影箱（27 格）", "layoutId": "generic_9x3" },
    ].concat(shulkerBoxOptions, [
        { "value": "dispenser", "label": "发射器（9 格）", "layoutId": "generic_3x3" },
        { "value": "dropper", "label": "投掷器（9 格）", "layoutId": "generic_3x3" },
        { "value": "hopper", "label": "漏斗（5 格）", "layoutId": "hopper_5" },
        { "value": "brewing_stand", "label": "酿造台（5 格）", "layoutId": "brewing_stand_5" },
        { "value": "furnace", "label": "熔炉（3 格）", "layoutId": "furnace_3" },
        { "value": "blast_furnace", "label": "高炉（3 格）", "layoutId": "furnace_3" },
        { "value": "smoker", "label": "烟熏炉（3 格）", "layoutId": "furnace_3" },
        { "value": "large_chest", "label": "大型箱子（54 格）", "layoutId": "generic_9x6" },
        { "value": "large_trapped_chest", "label": "大型陷阱箱（54 格）", "layoutId": "generic_9x6" },
        { "value": "chest_minecart", "label": "运输矿车（27 格）", "layoutId": "generic_9x3" },
        { "value": "chest_boat", "label": "运输船（27 格）", "layoutId": "generic_9x3" },
        { "value": "hopper_minecart", "label": "漏斗矿车（5 格）", "layoutId": "hopper_5" }
    ])
    
}
