// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
Item {
    id: root
    property bool active: false
    property bool loading: false
    default property Component component
    property var item: null
    onActiveChanged: item = active && component ? component.createObject(root) : (item ? (item.destroy(), null) : null)
    Component.onCompleted: if (active && component) item = component.createObject(root)
}
