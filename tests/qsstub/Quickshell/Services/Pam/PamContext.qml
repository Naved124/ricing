// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property string config: "login"
    property string configDirectory: ""
    property string user: ""
    property bool active: false
    property bool responseRequired: false
    property bool responseVisible: false
    property string message: ""
    property bool messageIsError: false
    signal completed(int result)
    signal error(int error)
    signal pamMessage()
    function start() { active = true; return true; }
    function respond(r) { active = false; completed(r === "right" ? 0 : 1); }
    function abort() { active = false; }
}
