pragma Singleton
import QtQuick


QtObject {

    property color background_n: "#1b1d27"
    property color background: "#aa1b1d27"
    property color foreground: "#aa41434f"
    readonly property color shadow: '#aa050505'
    property color glass_highlight: '#4bffffff'
    property color fired: "#aa92949c"
    property color pressed: "#aa6b6c74"
    property color text: "#ffffff"
    // 设置页可修改，全局控件会随之更新。
    property color border: "#00aaFF"
    property color banned: "#bbbbbb"
    readonly property color error: "#FF0000"

    readonly property color transparent: "transparent"
    readonly property color nest_light: "#10ffffff"
    readonly property color mask: "#33000000"

    function changeA(color,a){
        return Qt.rgba(color.r,color.g,color.b,a)
    }
      
}
