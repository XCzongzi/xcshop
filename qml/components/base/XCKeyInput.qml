import QtQuick
import xcshop

Item{
    id:root

    signal fieldContextChanged

    property string keyText : "键"
    property string fieldText : "请输入值"
    property int fieldX : field.x
    //property string context : field.text
    height: propertyText.height + field.height + 2
    

    function setContext(text){
        field.text = text
    }
    function getContext(){      //这里使用函数获取文本而不是直接使用属性是为了防止属性更新的滞后
        return field.text
    }



    XCText{
        id: propertyText
        xcText: root.keyText
        xcFontSize: 18
        onCenter: false
        boldFont: false
    }
    XCTextField{
        id: field
        width: root.width
        y: propertyText.height + 2
        placeholderText: root.fieldText
        onTextChanged: {
            root.fieldContextChanged()
        }
    }
}
