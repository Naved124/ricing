// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property var window: null
    property var item: null
    property rect rect: Qt.rect(0, 0, 0, 0)
    property int edges: 0
    property int gravity: 0
    function updateAnchor() {}
}
