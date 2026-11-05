pragma ComponentBehavior: Bound
import QtQuick
import xcshop

PopupFrame {
    id: root
    title: "将操作组继承至…"
    dialogWidth: 640
    dialogHeight: 400
    useGlobalElementRelay: true
    onAboutToOpen: selection.requestElementSelection()
    property var targetPaths: []
    property string validationMessage: ""
    function submit() {
        if (!selection.hasSelection)
            return;
        validationMessage = Global.operationInheritanceError(selection.selectedElementPath, targetPaths);
        if (!validationMessage.length)
            close(Global.projectRelativeElementPath(selection.selectedElementPath));
    }
    Keys.onEscapePressed: close(null)
    ElementSelection {
        id: selection
        objectName: "inheritanceDialogSelection"
        x: 24
        y: 82
        width: parent.width - 48
        selectionId: "item"
        onElementSelected: root.validationMessage = ""
        onSelectionCleared: root.validationMessage = ""
    }
    XCText {
        x: 24
        y: selection.y + selection.height + 10
        width: parent.width - 48
        xcText: root.validationMessage
        xcFontSize: 12
        textColor: Colors.error
        onCenter: false
        elide: Text.ElideRight
    }
    actions: [
        ActionButton { text: "取消"; onClicked: root.close(null) },
        ActionButton {
            objectName: "confirmOperationInheritance"
            text: "确认"
            primary: true
            enabled: selection.hasSelection
            onClicked: root.submit()
        }
    ]
}
