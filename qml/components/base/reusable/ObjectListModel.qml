import QtQuick

// ListModel 只负责稳定的行身份；保留原始 JS 对象，避免删除时索引重排串写数据。
ListModel {
    id: root
    property var objects: ({})
    property int nextKey: 0
    function add(value, animateInsertion) {
        var key = String(nextKey++);
        objects[key] = value;
        append({
            objectKey: key,
            animateInsertion: !!animateInsertion
        });
    }
    function value(key) {
        return objects[key];
    }
    function removeAt(index) {
        var key = get(index).objectKey;
        remove(index);
        delete objects[key];
    }
}
