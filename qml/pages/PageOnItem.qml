pragma ComponentBehavior: Bound
import QtQuick
import xcshop

BaseIOPage {
    id: root
    color: "transparent"
    workspace: true

    //元素读取
    function elementReading(){
        //此函数用于在页面创建时，将从项目文件中读取到的数据更新至控件中
        //有的数据使用属性绑定更新，而不依赖此函数

        //单选框&多属性编辑栏的属性更新必须使用函数，而不能使用属性绑定
    
        displayInput_selection.selected = root.eledata.display.selected
        displayInput_input.setElement(root.eledata.display.element, false)

        //Repeater中动态加载的组件的数据也需要使用函数来更新
        //由于数据是存储在数组中的，而Repeater使用的模型又是ListModel，所以需要先把数组中的数据同步到ListModel当中
        //并且在后续修改过程中，需要将数组与model中的数据同步更新

        if (!Array.isArray(root.eledata.cost))
            root.eledata.cost = []

        for(var i = 0; i < root.eledata.cost.length; i++ ){
            costListModel.append(root.eledata.cost[i])
        }

        for(var i = 0; i < eledata.trigger.length; i++ ){
            listModel.append(eledata.trigger[i])
        }

        Qt.callLater(function() { //稍后加载，一般用于含Repeater的ContentBar，以适应高度的初始化
            costInput.expand()
            displayInput.expand()
            triggerInput.expand()
        })

    }


    function itemIdFromInput(value){
        var text = value === undefined || value === null ? "" : String(value).trim()
        var match = text.match(/^([a-z0-9_.-]+(?::[a-z0-9_./-]+)?)/i)
        return match ? match[1] : ""
    }

    function itemTextureSource(value){
        var path = Global.getItemTexturePath(itemIdFromInput(value))
        return path.length ? "file:///" + path.replace(/\\/g, "/") : ""
    }



    //布局
    maxHeadContentCount: 2
    headContentMinWidth: itemInput.min_width + displayInput.min_width

    content_height: 
            !root.layout ? 
                itemInput.height + costInput.height + displayInput.height + triggerInput.height + 64
                : Math.max(itemInput.height + costInput.height, displayInput.height + triggerInput.height) + 48

    //内容
    ContentBar{
        id: itemInput
        //
        x: 16
        y: 16 - root.height_output
        //
        title: "物品ID"
        subtitle: "欲售出的物品ID+物品组件（默认为原版命名空间）"
        VariableTextField{
            id: itemInput_field
            x: 16
            y: 70
            width: parent.width - 32
            height: 256
            content: root.eledata.item
            onAccepted:{
                root.eledata.item = content; root.updateDataOut()
            }
            syntaxHighlightMode: 1
        }
        min_width: 400
        contentHeight: itemInput_field.y + itemInput_field.height + 18

        Image{
            width: 64
            height: width
            y: 16
            x: parent.width - width - 16
            source: root.itemTextureSource(itemInput_field.inputContent)
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
            visible: status === Image.Ready
            layer.enabled: visible
            layer.effect: XCShadow {
                shadowBlur: 0.55
                shadowHorizontalOffset: 2
                shadowVerticalOffset: 2
            }
        }
    }
    ContentBar{
        id:costInput
        delayExpand: true
        x: itemInput.x
        y: itemInput.y + itemInput.height + 8
        min_width: itemInput.min_width
        contentHeight: costInput_box.y + costInput_box.height + 16
        title: "触发代价"
        subtitle: "最终消耗为选择的多个代价元素之和"
        Column{
            id: costInput_box
            spacing: 8
            x: 16
            y: 64
            width: parent.width - 32
            Rectangle{
                width: parent.width
                height: 1
                color: Colors.banned
            }
            XCText{
                text: "设置购买此物所需的价格"
                onCenter: false
                y: 8
            }
            ListModel{
                id: costListModel
            }
            Repeater{
                id: costRepeater
                width: parent.width
                model: costListModel
                delegate: Item_costBar {
                    width: parent.width
                    required property var model
                    z: -model.index
                    index: model.index
                    modelData: root.eledata.cost[model.index]
                    onDeleteClicked: {
                        if (model.index < costListModel.count - 1) {
                            costRepeater.itemAt(model.index + 1).nearest = true
                            for (var i = model.index + 1; i < costListModel.count; i++)
                                costRepeater.itemAt(i).afterDeleting(height, model.index)
                        } else {
                            root.eledata.cost.splice(model.index, 1)
                            root.updateDataOut()
                            costListModel.remove(model.index, 1)
                        }
                    }
                    onDeleteAnimFinishied: function(currentIndex) {
                        root.eledata.cost.splice(currentIndex, 1)
                        root.updateDataOut()
                        costListModel.remove(currentIndex, 1)
                    }
                    onUpdateData: {
                        root.eledata.cost[model.index] = modelData
                        root.updateDataOut()
                    }
                }
            }
            TextButton{
                id: costInput_add
                height: 32
                width: 150
                z: -999
                radius: 8
                buttonColor: Colors.changeA(Colors.background, 0.38)
                firedColor: Colors.changeA(Colors.fired, 0.72)
                pressedColor: Colors.changeA(Colors.border, 0.55)

                text: "＋  添加代价元素"
                textSize: 14
                textColor: Colors.banned
                boldFont: false

                onClicked:{
                    root.eledata.cost.push({"element":"", "amount":"1"})
                    root.updateDataOut()
                    costListModel.append(root.eledata.cost[root.eledata.cost.length - 1])
                }
            }
        }
    }


    ContentBar{
        id: displayInput
        // 等待文件数据读入后，再按保存的展示选项播放展开动画。
        delayExpand: true
        //
        x: root.layout ? itemInput.x + itemInput.width + 8 : 16
        y: root.layout ? itemInput.y : costInput.y + costInput.height + 8
        //
        min_width: 520
        contentHeight: displayInput_selection.selected == 1
                ? displayInput_input.y + displayInput_input.height + 24
                : displayInput_selection.y + displayInput_selection.height + 22

        title: "商品展示"
        RadioGroup{
            id:displayInput_selection
            y: 54
            text: ""
            options: ["仅原物品","额外添加展示元素"]
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked:{
                root.eledata.display.selected = selected; root.updateDataOut()
            }
        }
        ElementSelection{
            id: displayInput_input
            selectionId: "display"
            visible: displayInput_selection.selected == 1
            anchors.horizontalCenter: parent.horizontalCenter
            y: displayInput_selection.y + displayInput_selection.height + 16
            onElementSelected: function(filePath) {
                root.eledata.display.element = filePath
                root.updateDataOut()
            }
            onSelectionCleared: {
                root.eledata.display.element = "path"
                root.updateDataOut()
            }
        }
    }
    ContentBar{
        id:triggerInput
        delayExpand: true
        //
        x: displayInput.x
        y: displayInput.y + displayInput.height + 8
        //
        min_width: displayInput.min_width
        contentHeight: triggerBar_add.y + triggerBar_add.height + 16
        title: "触发规则"
        subtitle: "分别定义物品被任意方式取得或掷出后应执行的操作"
        
        Column{
            id: triggerBox
            width: parent.width - 32
            x: 16
            y: 68
            spacing: 16
            
            ListModel{
                id: listModel
            }
            Repeater{
                id: triggerRepeater
                width: parent.width
                model: listModel

                delegate: Item_triggerBar{
                    width: parent.width
                    required property var model
                    z: -model.index
                    index: model.index
                    modelData: root.eledata.trigger[model.index]
                    onDeleteClicked:{
                        triggerBar_add_y_animation.enable()
                        if(model.index < listModel.count - 1){//判断是否为最后一个栏位，以确认是否启用上滑动画
                            triggerRepeater.itemAt(model.index + 1).nearest = true
                            for(var i = model.index + 1; i < listModel.count; i++){
                                triggerRepeater.itemAt(i).afterDeleting(height,model.index)
                            }
                        }else{
                            root.eledata.trigger.splice(model.index,1);root.updateDataOut()
                            listModel.remove(model.index,1)
                        }
                    }
                    onDeleteAnimFinishied:function(currentIndex) {
                        root.eledata.trigger.splice(currentIndex,1);root.updateDataOut()
                        listModel.remove(currentIndex,1)
                    }

                    onUpdateData:{
                        root.eledata.trigger[model.index] = modelData; root.updateDataOut()
                    }
                }
            }
            onHeightChanged:{
                triggerBar_add_y_animation.start()
            }
        }
        TextButton{
                id: triggerBar_add
                height: 100
                width: triggerBox.width
                y: 80
                x: 16
                radius: 10
                buttonColor: Colors.changeA(Colors.background, 0.38)
                firedColor: Colors.changeA(Colors.fired, 0.72)
                pressedColor: Colors.changeA(Colors.border, 0.55)

                text: "＋  添加触发规则"
                textSize: 14
                textColor: Colors.banned
                boldFont: false

                NumberAnimation{
                    id: triggerBar_add_y_animation
                    target: triggerBar_add
                    property: "y"
                    to: triggerBox.y + triggerBox.height + triggerBox.spacing
                    duration: 0
                    onFinished: duration = 0
                    function enable(){
                        duration = 120
                    }
                }

                onClicked:{
                    triggerBar_add_y_animation.enable()
                    root.eledata.trigger.push(
                        {"mode":{"selected":0,"filter":{"selected":0,"options":[-1,0]}},"execute":{"selected":0,"selections":["",""]}}
                        ); root.updateDataOut()
                    listModel.append(root.eledata.trigger[root.eledata.trigger.length - 1])
                }
            }
        
    }
}
