// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property string name: "DP-1"
    property int x: 0
    property int y: 0
    property int width: 1920
    property int height: 1080
    property real scale: 1
    property bool focused: true
    property var activeWorkspace: null
    property var lastIpcObject: ({ dpmsStatus: true })
}
