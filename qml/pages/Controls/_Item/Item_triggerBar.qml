import QtQuick
import xcshop


Rectangle{
    id: root
    color: Colors.transparent
    radius: frame.radius
    width: 500
    height: execute.y + execute.height + 20
    enabled: opacity > 0.01

    property int index
    property var modelData
    property bool nearest: false//用于上移对象播放删除动画后，标记该对象为相邻对象的变量

    signal deleteClicked()
    signal deleteAnimFinishied(int currentIndex)
    signal updateData()

    Component.onCompleted:{
        Qt.callLater(function(){
            trigger_radioGroup.selected = root.modelData.mode.selected
            comboBox_root.selected = root.modelData.mode.filter.selected
            
            var optionData = root.modelData.mode.filter.options[0]
            comboBox_numfilter.selected = optionData == -1 ? 0 : optionData == -2 ? 1 : 2
            //若读取到的optionData为-1，就是左键检测；-2即右键检测；除此之外就是自定义的内容
            execute_radioGroup.selected = root.modelData.execute.selected
        })
    }

    //删除动画：
    //当用户点击删除按钮后，先在当前对象内部播放右滑的删除动画，再通过deleteClicked信号传送到外边
    //外边接到信号后，将播放该对象以下对象的填补动画，即上滑动画
    //填补动画会改变Item_triggerBar中的offset变量来设置偏移量
    //当偏移量动画播放完毕后，下一个对象已经移动到了当前对象的位置，这时候删除当前对象，并把下一对象的偏移量立即设置为零
    //这时候，下一对象在视觉上的的位置就不会改变
    function afterDeleting(offset,index){
        afterDeletingAnim.offset = offset
        afterDeletingAnim.currentIndex = index
        afterDeletingAnim.start()
    }
    NumberAnimation{
        id: afterDeletingAnim
        property int offset
        property int currentIndex
        target: frame
        property: "y"
        to: -offset
        duration: 120
        easing.type: Easing.InCubic
        onFinished: {
            frame.y = 0
            if(root.nearest){//只让与被删除对象相邻的返回信号，防止信号被多次触发
                root.nearest = false
                root.deleteAnimFinishied(currentIndex)
            }
        }
    }
    

    Behavior on height{     //配合函数输入框的高度动画
        enabled: field_function.visible
        NumberAnimation{
            duration: 120
            easing.type: Easing.InOutQuad
        }
    }
    Rectangle{
        id: frame
        width: parent.width
        height: parent.height
        color: Colors.changeA(Colors.foreground, 0.76)
        radius: 12
        border.width: 1
        border.color: Colors.changeA(Colors.text, 0.10)

        layer.enabled: true
        layer.effect: XCShadow{
            shadowColor: Colors.changeA(Colors.shadow, 0.55)
            shadowBlur: 0.55
            shadowVerticalOffset: 3
            shadowHorizontalOffset: 0
        }

        Rectangle {
            id: cardHeader
            width: parent.width
            height: 32
            radius: 9
            color: Colors.changeA(Colors.background, 0.38)
            border.width: 1
            border.color: Colors.changeA(Colors.text, 0.07)

            Rectangle {
                x: 1
                y: 4
                width: 4
                height: 24
                radius: 2
                color: Colors.border
            }
            XCText {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                xcText: "规则"
                onCenter: false
                xcFontSize: 13
            }
        }

        Rectangle{
            id: ctrlBar
            z: 3
            color: Colors.changeA(Colors.foreground, 0.94)
            width: 32 + 16 + ctrlBar_text.width
            height: 32
            x: parent.width - width
            radius: root.radius
            topLeftRadius: 0
            topRightRadius: radius
            bottomLeftRadius: radius
            bottomRightRadius: 0
            border.width: 1
            border.color: Colors.changeA(Colors.text, 0.10)
            
            ImageButton{
                id:ctrlBar_btn
                btnSize: 32
                radius: root.radius
                topLeftRadius: 0
                topRightRadius: radius
                bottomLeftRadius: radius
                bottomRightRadius: 0
                btnbackground: Colors.changeA(Colors.error, 0.72)
                btnfired: Colors.changeA(Colors.error, 0.90)
                btnpressed: Colors.error
                onClicked:deleteAnim.start()
            }
            NumberAnimation{
                id: deleteAnim
                target: root
                property: "x"
                to: root.width
                duration: 200
                onFinished: {
                    root.opacity = 0
                    root.deleteClicked()
                }
                easing.type: Easing.InCubic
            }
            XCText{
                id:ctrlBar_text
                x: parent.width - width - 8
                xcText: root.index + 1
                onCenter: false
                onVCenter: true
                xcFontSize: 16
                boldFont: false
                textColor: Colors.banned
            }
            
        }

        Rectangle{
            id: trigger
            z: 2
            y: 48
            color: Colors.transparent
            height: trigger_radioGroup.selected ? trigger_radioGroup.y + trigger_radioGroup.height + 12 : f2.y + f2.height + 12
            width: parent.width


            RadioGroup{
                id: trigger_radioGroup
                x: 16
                y: 0
                text: "触发方式"
                options: ["取得商品","掷出商品"]
                onClicked:{
                    root.modelData.mode.selected = selected; root.updateData()
                }
            }
            ComboBox{
                id: comboBox_root
                visible: !trigger_radioGroup.selected
                z: 2
                x: 16
                y: trigger_radioGroup.y + trigger_radioGroup.height + 10
                options: ["无筛选","数量筛选","栏位筛选"]
                onClicked:{
                    root.modelData.mode.filter.selected = selected; root.updateData()
                }
            }
            Rectangle{
                id: f2
                visible: comboBox_root.visible && comboBox_root.selected != 0
                x: comboBox_root.x + comboBox_root.width + 12
                y: comboBox_root.y
                width: parent.width - x - 16
                height: comboBox_root.height
                color: Colors.transparent
                BranchBar{
                    visible: comboBox_root.selected == 1
                    anchors.fill: parent
                    ComboBox{
                        id: comboBox_numfilter
                        z: 1
                        x: 8
                        options: ["全部(左键检测)","少于全部(右键检测)","自定义"]
                        onClicked:{
                            if(selected == 0){//存储的：-1:全部；-2:右键；0+:自定义
                                root.modelData.mode.filter.options[0] = -1; root.updateData()
                            }else if(selected == 1){
                                root.modelData.mode.filter.options[0] = -2; root.updateData()
                            }else{
                                field_numfilter.text = "0"
                            }
                            
                        }
                    }
                    XCTextField{
                        id: field_numfilter
                        visible: comboBox_numfilter.selected == 2
                        x: comboBox_numfilter.width + 12
                        width: 32
                        horizontalAlignment: TextInput.AlignHCenter
                        text: comboBox_numfilter.selected == 2 ? root.modelData.mode.filter.options[0] : "0"
                        onEditingFinished:{
                            root.modelData.mode.filter.options[0] = +text; root.updateData()
                        }
                    }
                }
                BranchBar{
                    visible: comboBox_root.selected == 2
                    anchors.fill: parent
                    XCText{
                        x: 8
                        id: slotfilter_tabel
                        xcText: "指定栏位："
                        onCenter: false
                        onVCenter: true
                    }
                    XCTextField{
                        id: field_slotfilter
                        x: slotfilter_tabel.width + 12
                        width: 32
                        horizontalAlignment: TextInput.AlignHCenter
                        text: root.modelData.mode.filter.options[1]
                        onEditingFinished:{
                            root.modelData.mode.filter.options[1] = +text; root.updateData()
                        }
                    }
                }
            }
            
        }

        Rectangle{
            id: execute
            z: 1
            y: trigger.y + trigger.height + 8
            width: parent.width
            height: execute_radioGroup.selected == 0 ? execute_radioGroup.y + execute_radioGroup.height + 12 : execute_f2.y + execute_f2.height + 12
            color: Colors.transparent
            Rectangle{
                width: parent.width - 32
                x: 16
                height: 1
                color: Colors.changeA(Colors.text, 0.10)
            }
            RadioGroup{
                id: execute_radioGroup
                x: 16
                y: 12
                text: "执行操作"
                options: ["获得物品","执行指令","执行函数"]
                onClicked:{
                    root.modelData.execute.selected = selected; root.updateData()
                }
            }
            BranchBar{
                id: execute_f2
                visible: execute_radioGroup.selected != 0
                x: 16
                y: execute_radioGroup.y + execute_radioGroup.height + 10
                width: parent.width - 32
                height: execute_radioGroup.selected == 1 ? field_command.height + 8 : field_function.height + 8

                Row{
                    visible: execute_radioGroup.selected == 1
                    x: 8
                    width: parent.width
                    XCText{
                        id: text_command
                        onCenter:false
                        onVCenter:true
                        xcText:"输入指令："
                    }
                    XCTextField{
                        id: field_command
                        width: parent.width - text_command.width - 16
                        text: root.modelData.execute.selections[0]
                        onEditingFinished:{
                            root.modelData.execute.selections[0] = text; root.updateData()
                        }
                    }
                }
                VariableTextArea{
                    id: field_function
                    visible: execute_radioGroup.selected == 2
                    x: 8
                    width: parent.width - 16
                    height: 128
                    content: root.modelData.execute.selections[1]
                    onAccepted:{
                        root.modelData.execute.selections[1] = content; root.updateData()
                    }
                }
            }
        }
    }
}     
        
        
        
        
