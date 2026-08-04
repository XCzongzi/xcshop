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
        
        
        Qt.callLater(function() { //稍后加载，一般用于含Repeater的ContentBar，以适应高度的初始化
            displayInput.startExpandAnimation() 
            
            triggerBar_add.height = 100
            triggerBar_text.visible = false
            triggerBox.visible = true
            triggerInput.startExpandAnimation() 
            })

        //Repeater中动态加载的组件的数据也需要使用函数来更新
        //由于数据是存储在数组中的，而Repeater使用的模型又是ListModel，所以需要先把数组中的数据同步到ListModel当中
        //并且在后续修改过程中，需要将数组与model中的数据同步更新

        for(var i = 0; i < eledata.trigger.length; i++ ){
            listModel.append(eledata.trigger[i])
        }

    }



    //布局
    property int combined_width: itemInput.min_width + triggerInput.min_width + 16 * 2 + 8
    property int workspaceTop: 16

    layout: combined_width < width
    content_height: 
            !root.layout ? 
                workspaceTop + itemInput.height + displayInput.height + triggerInput.height + 40
                : workspaceTop + Math.max(itemInput.height + displayInput.height + 20, triggerInput.height) + 24

    //内容
    ContentBar{
        id: itemInput
        //
        x: 16
        y: root.workspaceTop - root.height_output
        width: root.layout ? (root.width - root.combined_width) / 2 + min_width : parent.width - 32
        //
        XCText{
            id: itemInput_propertyText
            y: 18
            x: 16
            xcText: "物品ID"
            xcFontSize: 18
            onCenter: false
        }
        XCText{
            x: 16
            y: 46
            xcText: "欲售出的物品ID+物品组件（默认为原版命名空间）"
            xcFontSize: 12
            onCenter: false
            boldFont: false
            textColor: Colors.banned
        }
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
        }
        min_width: 400
        height: itemInput_field.y + itemInput_field.height + 18
    }
    ContentBar{
        id: displayInput
        // 等待文件数据读入后，再按保存的展示选项播放展开动画。
        deferInitialExpand: true
        //
        x: 16
        y: itemInput.y + itemInput.height + 8
        width: root.layout ? (root.width - root.combined_width) / 2 + min_width : parent.width - 32
        //
        min_width: itemInput.min_width
        height: displayInput_selection.selected == 1
                ? displayInput_input.y + displayInput_input.height + 24
                : displayInput_selection.y + displayInput_selection.height + 22

        XCText { x: 16; y: 18; xcText: "商品展示"; xcFontSize: 18; onCenter: false }
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
        deferInitialExpand: true
        //
        x: root.layout ? itemInput.x + itemInput.width + 8 : 16
        y: root.layout ? root.workspaceTop - root.height_output : displayInput.y + displayInput.height + 8
        width: root.layout ? (root.width - root.combined_width) / 2 + min_width : parent.width - 32
        //
        min_width: 520
        resizeAnimationEnabled: false
        height: triggerBox.visible ? triggerBox.implicitHeight + 82 : 100
        XCText{
            id: triggerBar_text
            xcFontSize: 25
            text:"加载中..."
        }
        XCText {
            x: 16
            y: 18
            xcText: "触发规则"
            xcFontSize: 18
            onCenter: false
        }
        XCText {
            x: 16
            y: 46
            xcText: "分别定义物品被任意方式取得或掷出后应执行的操作"
            xcFontSize: 12
            onCenter: false
            boldFont: false
            textColor: Colors.banned
        }
        
        Column{
            id: triggerBox
            visible: false
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
                    onDeleteAnimFinishied:{
                        root.eledata.trigger.splice(currentIndex,1);root.updateDataOut()
                        listModel.remove(currentIndex,1)
                    }

                    onUpdateData:{
                        root.eledata.trigger[model.index] = modelData; root.updateDataOut()
                    }
                }
            }
            

            ImageButton{
                id: triggerBar_add
                height: 99
                width: triggerBox.width
                z: -999
                btnRadius: 10
                btnbackground: Colors.changeA(Colors.background, 0.38)
                btnfired: Colors.changeA(Colors.fired, 0.72)
                btnpressed: Colors.changeA(Colors.border, 0.55)
                XCText {
                    anchors.centerIn: parent
                    xcText: "＋  添加触发规则"
                    xcFontSize: 14
                    textColor: Colors.banned
                    boldFont: false
                }
                onClicked:{
                    root.eledata.trigger.push(
                        {"mode":{"selected":0,"filter":{"selected":0,"options":[-1,0]}},"execute":{"selected":0,"selections":["",""]}}
                        ); root.updateDataOut()
                    listModel.append(root.eledata.trigger[root.eledata.trigger.length - 1])
                }
            }
        }
        
    }
    function pageOnCompleted(){
        triggerBox.forceLayout()
    }
    

    
    

}
