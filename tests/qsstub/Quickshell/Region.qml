// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property var item: null
    property int x: 0
    property int y: 0
    property int width: 0
    property int height: 0
    property int intersection: 0
    property int shape: 0
    default property list<QtObject> regions
}
