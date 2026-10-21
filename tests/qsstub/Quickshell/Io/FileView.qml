// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool blockLoading: false
    property bool blockWrites: false
    property bool printErrors: true
    property bool preload: true
    property bool atomicWrites: true
    default property QtObject adapter
    signal fileChanged()
    signal adapterUpdated()
    signal loadFailed(int error)
    signal saved()
    signal saveFailed(int error)
    signal loaded()
    function text() { return ""; }
    function data() { return null; }
    function reload() {}
    function writeAdapter() {}
    function setText(t) {}
}
