import QtQuick
import xcshop
import "../../js/WorkspaceSchema.js" as Schema

BaseIOPage {
    id: root
    color: Colors.transparent
    workspace: true
    property int previewRevision: 0
    function changed() {
        previewRevision++;
        updateDataOut();
    }
    function elementReading() {
        if (!eledata.operation || typeof eledata.operation.order !== "string")
            throw new Error("此页面只支持操作组展示格式，请使用新建项目");
        operationEditor.load();
        memberEditor.load();
        loadFrame();
        loadHint();
        previewRevision++;
    }
    function loadFrame() {
        var target = frameTabs.selected === 3 ? eledata.operation : eledata.frame;
        if (target && frameTabs.selected >= 0)
            frameText.setContent(target[["head", "end", "separator", "separator"][frameTabs.selected]]);
    }
    function loadHint() {
        if (!eledata.hint || hintTabs.selected < 0)
            return;
        var hint = eledata.hint[hintTabs.selected === 0 ? "success" : "fail"];
        hintText.setContent(hint.text);
        hintSound.text = hint.sound;
    }
    maxHeadContentCount: 3
    headContentMinWidth: operationBar.min_width + memberBar.min_width + frameBar.min_width
    readonly property real columnWidth: root.layout ? operationBar.min_width + root.contentWidthEnhance : root.width - 32
    readonly property real memberContentHeight: 54 + Math.max(operationEditor.height, memberEditor.height) + 16
    content_height: Math.max(operationBar.y + operationBar.height, memberBar.y + memberBar.height, hintBar.y + hintBar.height) + root.height_output + 16
    ContentBar {
        id: previewBar
        objectName: "displayPreviewBar"
        x: 16
        y: 16 - root.height_output
        width: root.layout ? root.columnWidth * 2 + 16 : root.width - 32
        title: "预览"
        contentHeight: tooltip.y + tooltip.height + 24
        Flow {
            id: counts
            x: 16
            y: 52
            width: parent.width - 32
            spacing: 16
            Row {
                spacing: 8
                XCText {
                    xcText: "操作数"
                    onCenter: false
                    onVCenter: true
                    height: 28
                    xcFontSize: 12
                    textColor: Colors.banned
                }
                XCTextField {
                    width: 48
                    height: 28
                    text: "2"
                    horizontalAlignment: TextInput.AlignHCenter
                    validator: IntValidator {
                        bottom: 1
                        top: 16
                    }
                    onEditingFinished: {
                        tooltip.demoOperationCount = Math.max(1, Math.min(16, Number(text) || 1));
                        text = tooltip.demoOperationCount;
                    }
                }
            }
            Row {
                spacing: 8
                XCText {
                    xcText: "每操作代价数"
                    onCenter: false
                    onVCenter: true
                    height: 28
                    xcFontSize: 12
                    textColor: Colors.banned
                }
                XCTextField {
                    width: 48
                    height: 28
                    text: "3"
                    horizontalAlignment: TextInput.AlignHCenter
                    validator: IntValidator {
                        bottom: 0
                        top: 16
                    }
                    onEditingFinished: {
                        tooltip.demoElementCount = Math.max(0, Math.min(16, Number(text) || 0));
                        text = tooltip.demoElementCount;
                    }
                }
            }
        }
        MinecraftTooltipPreview {
            id: tooltip
            objectName: "operationsPreview"
            anchors.horizontalCenter: parent.horizontalCenter
            y: counts.y + counts.height + 20
            maximumWidth: previewBar.width - 32
            format: {
                root.previewRevision;
                return root.eledata.operation ? JSON.parse(JSON.stringify(root.eledata)) : Schema.display();
            }
        }
    }
    ContentBar {
        id: operationBar
        objectName: "displayOperationBar"
        title: "操作组成员"
        x: 16
        y: previewBar.y + previewBar.height + 16
        min_width: 400
        contentHeight: root.memberContentHeight
        XCCheckBox {
            id: operationEnabled
            objectName: "operationFormatEnabled"
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 18
            text: "启用"
            checked: root.eledata.operation ? !!root.eledata.operation.enabled : false
            onToggled: function (value) {
                root.eledata.operation.enabled = value;
                root.changed();
            }
        }
        DisplayPairEditor {
            id: operationEditor
            objectName: "operationFormatEditor"
            x: 16
            y: 54
            width: parent.width - 32
            value: root.eledata.operation || null
            firstKey: "title"
            secondKey: "cost"
            firstLabel: "操作名称"
            secondLabel: "代价文本"
            editSecondStyle: false
            orders: ["title_then_cost", "cost_then_title"]
            onEdited: root.changed()
        }
    }
    ContentBar {
        id: memberBar
        objectName: "displayMemberBar"
        title: "代价组成员"
        min_width: 400
        x: root.layout ? operationBar.x + operationBar.width + 16 : 16
        y: root.layout ? operationBar.y : operationBar.y + operationBar.height + 16
        contentHeight: root.memberContentHeight
        DisplayPairEditor {
            id: memberEditor
            objectName: "costFormatEditor"
            x: 16
            y: 54
            width: parent.width - 32
            value: root.eledata.member || null
            onEdited: root.changed()
        }
    }
    ContentBar {
        id: frameBar
        objectName: "displayFrameBar"
        title: "框架"
        min_width: 400
        x: root.layout ? memberBar.x + memberBar.width + 16 : 16
        y: root.layout ? previewBar.y : memberBar.y + memberBar.height + 16
        contentHeight: frameTabs.y + frameTabs.height + 16
        MultiPropertyEdit {
            id: frameTabs
            objectName: "frameProperties"
            x: 16
            y: 48
            width: parent.width - 32
            options: ["头部文本", "尾部文本", "分隔文本", "代价分隔"]
            onSelectedChanged: root.loadFrame()
            DisplayTextEditor {
                id: frameText
                objectName: "frameTextEditor"
                width: parent.width
                caption: frameTabs.selected === 3 ? "同一操作内的代价分隔" : frameTabs.selected === 2 ? "操作之间的分隔" : "文本内容"
                onEdited: function (value) {
                    if (!root.dataLoaded)
                        return;
                    var target = frameTabs.selected === 3 ? root.eledata.operation : root.eledata.frame;
                    target[["head", "end", "separator", "separator"][frameTabs.selected]] = value;
                    root.changed();
                }
            }
        }
    }
    ContentBar {
        id: hintBar
        objectName: "displayHintBar"
        title: "提示信息"
        min_width: 400
        x: frameBar.x
        y: frameBar.y + frameBar.height + 16
        contentHeight: hintTabs.y + hintTabs.height + 16
        MultiPropertyEdit {
            id: hintTabs
            x: 16
            y: 48
            width: parent.width - 32
            options: ["成功信息", "失败信息"]
            onSelectedChanged: root.loadHint()
            Item {
                width: parent.width
                height: hintSound.y + hintSound.height
                DisplayTextEditor {
                    id: hintText
                    width: parent.width
                    onEdited: function (value) {
                        if (!root.dataLoaded)
                            return;
                        root.eledata.hint[hintTabs.selected === 0 ? "success" : "fail"].text = value;
                        root.changed();
                    }
                }
                XCText {
                    id: soundLabel
                    y: hintText.height + 14
                    xcText: "音效"
                    onCenter: false
                    xcFontSize: 12
                    textColor: Colors.banned
                }
                XCTextField {
                    id: hintSound
                    y: soundLabel.y + soundLabel.height + 8
                    width: parent.width
                    placeholderText: "留空表示不播放音效"
                    onEditingFinished: {
                        if (!root.dataLoaded)
                            return;
                        root.eledata.hint[hintTabs.selected === 0 ? "success" : "fail"].sound = text;
                        root.changed();
                    }
                }
            }
        }
    }
}
