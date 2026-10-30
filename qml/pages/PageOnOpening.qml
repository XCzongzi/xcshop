import QtQuick
import xcshop
import QtQuick.Layouts
import QtQuick.Controls
import "qrc:/assets/js/request.js" as XHR

BasePage {
    id: root
    color: "transparent"
    XCText{
        id:xct
        xcText: "打开一个UI商店项目"
        xcFontSize: 24
        onCenter: false
        y: 50
    }


    XCTextField {
        id: urlTextField
        x: 50
        width:500
        text: "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        Layout.fillWidth: true
    }
    TextButton {
        text: qsTr("Send!")
        onClicked: XHR.sendRequest(urlTextField.text, function(response) {
            
            const myJson = JSON.parse(response.content)
            xct.xcText = JSON.stringify(myJson.latest)


        });
    }

    TextButton{
        text:"输出键值对"
        y: 100
        onClicked:{
            const key = "message";
            const textValue = jsonInput.text;

            // 方法 1：直接声明对象
            
            const jsonObj = {
                [key]: textValue // 动态键名（ES6 语法）
            };
            xct.xcText = JSON.stringify(jsonObj)
        }
    }
    XCTextField{
        id: jsonInput
        y:120
        height: 50
        width: 300
    }


}
