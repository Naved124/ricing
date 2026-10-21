// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.
import QtQuick
QtObject {
    property string target: ""
    property bool enabled: true
    Component.onCompleted: IpcRegistry.handlers[target] = this
}
