import QtQuick
import xcshop

Text{
    id:root
    property string xcText: ""
    property int xcFontSize: 16
    property bool onCenter: true
    property bool onVCenter: false
    property bool onHCenter: false
    property bool boldFont: true
    property bool underlineFont: false
    property color textColor: Colors.text
    property bool xcWrapMode: false


    x: onCenter || onHCenter? (parent.width-root.width)/2 - 1 : 0
    y: onCenter || onVCenter? (parent.height-root.height)/2 : 0
    text: qsTr(xcText)
    color: textColor
    font.pixelSize: xcFontSize
    font.family: "微软雅黑"
    font.bold: boldFont
    font.underline: underlineFont
    elide: Text.ElideRight
    wrapMode: xcWrapMode? TextInput.Wrap : TextInput.NoWrap

}