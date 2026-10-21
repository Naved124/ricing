// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property bool running: false
    property var command: []
    property var environment: ({})
    property bool clearEnvironment: false
    property string workingDirectory: ""
    property var stdout: null
    property var stderr: null
    property bool stdinEnabled: false
    property int processId: 0
    signal started()
    signal exited(int exitCode, int exitStatus)
    function signal(sig) {}
    function write(data) {}
    function startDetached() {}
}
