pragma Singleton
import QtQuick

QtObject{


    property string content: "xcshop是一款由XCzongzi开发的服务于游戏Minecraft的工具软件。\nxcshop控制台输出..."

    function output(text,hideHead){
        content += hideHead? "\n" + text : "\nconsole output: " + text
    }

}