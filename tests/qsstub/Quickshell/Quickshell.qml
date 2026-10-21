// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

pragma Singleton
import QtQuick
QtObject {
    readonly property var screens: [
        Qt.createQmlObject('import Quickshell; Screen { name: "DP-1"; x: 0; y: 0; width: 1920; height: 1080 }', this),
        Qt.createQmlObject('import Quickshell; Screen { name: "HDMI-A-1"; x: 1920; y: 0; width: 2560; height: 1440; devicePixelRatio: 1.25 }', this)
    ]
    readonly property string shellDir: ""
    readonly property string configDir: ""
    property var log: []
    function env(name) { return name === "HOME" ? "/tmp/qsstub-home" : ""; }
    function execDetached(args) { log.push(args); }
    function statePath(f) { return "/tmp/qsstub-home/state/" + f; }
    function cachePath(f) { return "/tmp/qsstub-home/cache/" + f; }
    function dataPath(f) { return "/tmp/qsstub-home/data/" + f; }
    function shellPath(f) { return f; }
    function iconPath(name, fallback) { return ""; }
    function reload(hard) {}
    function inhibitReloadPopup() {}
}
