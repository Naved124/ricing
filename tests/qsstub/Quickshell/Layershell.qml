// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property int layer: 2
    property string namespace: ""
    property int keyboardFocus: 0
    property int exclusiveZone: 0
    property var screen: null
}
