import QtQuick

// Main.qml 的单实例弹窗入口。被加载的组件可选实现 open()、close(result)
// 并在完成关闭动画后发出 closed(result) 信号。
Loader {
    id: root
    z: 1000
    active: false
    asynchronous: true

    property var pendingProperties: ({})
    property var closeCallback: null

    function open(component, properties, callback) {
        clear()
        pendingProperties = properties || ({})
        closeCallback = callback || null
        active = true
        sourceComponent = component
    }

    function close(result) {
        if (item && typeof item.close === "function")
            item.close(result)
        else
            finish(result)
    }

    function finish(result) {
        var callback = closeCallback
        clear()
        if (callback)
            callback(result)
    }

    function clear() {
        active = false
        sourceComponent = undefined
        pendingProperties = ({})
        closeCallback = null
    }

    onLoaded: {
        for (var name in pendingProperties)
            item[name] = pendingProperties[name]
        if (typeof item.open === "function")
            item.open()
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true
        function onClosed(result) {
            root.finish(result)
        }
    }
}
