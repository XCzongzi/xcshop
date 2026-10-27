import QtQuick
import xcshop

ResizableEditor {
    id: root
    input: textArea
    XCTextArea{
        id: textArea
        objectName: "variableTextAreaInput"
        highlightMacros: root.highlightMacros
        width: parent.width
        height: root.inputHeight
        onEditingFinished: root.commit()
    }
}
