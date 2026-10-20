pragma ComponentBehavior: Bound
import QtQuick
import xcshop

ContentBar {
    id: root

    property var counts: ({ "UI": 0, "Item": 0, "Cost": 0, "Display": 0 })
    property int registeredShopCount: 0
    property int validShopCount: 0
    property int referencedUiCount: 0
    property int totalElementCount: Number(counts.UI || 0) + Number(counts.Item || 0)
                                    + Number(counts.Cost || 0) + Number(counts.Display || 0)

    signal refreshRequested()

    title: "信息"
    subtitle: totalElementCount + " 个元素"
    contentHeight: 438
    expanded: true
    padding: 20

    component CountCell: Rectangle {
        property string typeName: ""
        property int count: 0
        width: (countGrid.width - countGrid.columnSpacing) / 2
        height: 42
        radius: 7
        color: Colors.changeA(Colors.background, 0.28)

        Image {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            source: "qrc:/assets/gui/element/" + parent.typeName + ".png"
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
        }
        XCText {
            x: 29
            y: 4
            width: parent.width - x - 4
            xcText: String(parent.count)
            onCenter: false
            xcFontSize: 15
        }
        XCText {
            x: 29
            y: 23
            width: parent.width - x - 4
            xcText: parent.typeName
            onCenter: false
            xcFontSize: 8
            boldFont: false
            textColor: Colors.banned
        }
    }

    Item {
        x: root.padding
        y: 76
        width: parent.width - root.padding * 2
        height: parent.height - y - 20

        Grid {
            id: countGrid
            width: Math.max(104, parent.width * 0.54)
            columns: 2
            columnSpacing: 8
            rowSpacing: 10

            CountCell { typeName: "UI"; count: Number(root.counts.UI || 0) }
            CountCell { typeName: "Item"; count: Number(root.counts.Item || 0) }
            CountCell { typeName: "Cost"; count: Number(root.counts.Cost || 0) }
            CountCell { typeName: "Display"; count: Number(root.counts.Display || 0) }
        }

        Column {
            id: details
            x: countGrid.width + 16
            width: parent.width - x
            spacing: 6

            component DetailRow: Item {
                property string label: ""
                property string value: ""
                width: details.width
                height: 18

                XCText {
                    width: parent.width * 0.68
                    xcText: parent.label
                    onCenter: false
                    onVCenter: true
                    xcFontSize: 9
                    boldFont: false
                    textColor: Colors.banned
                }
                XCText {
                    anchors.right: parent.right
                    width: parent.width * 0.30
                    xcText: parent.value
                    onCenter: false
                    onVCenter: true
                    horizontalAlignment: Text.AlignRight
                    xcFontSize: 10
                }
            }

            DetailRow { label: "已注册"; value: String(root.registeredShopCount) }
            DetailRow { label: "有效"; value: String(root.validShopCount) }
            DetailRow { label: "使用 UI"; value: String(root.referencedUiCount) }
            DetailRow { label: "无效"; value: String(Math.max(0, root.registeredShopCount - root.validShopCount)) }
        }
    }
}
