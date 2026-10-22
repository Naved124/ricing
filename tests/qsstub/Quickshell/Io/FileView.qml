// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens,
// except for Satsuei's files (a path with /satsuei/ in it): those are read
// from disk (qs_smoke allows XHR file reads), watched by polling, and written
// in memory, so a test can drive the shell through its theme.json.

import QtQuick
QtObject {
    id: view
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
    property string _text: ""
    property bool _real: path.indexOf("/satsuei/") >= 0
    function _read() {
        const x = new XMLHttpRequest();
        try {
            x.open("GET", "file://" + path, false);
            x.send();
        } catch (e) { return null; }
        return x.status === 200 || x.status === 0 ? (x.responseText || null) : null;
    }
    function text() { return _text; }
    function data() { return null; }
    function reload() {
        if (!_real) return;
        const t = _read();
        if (t === null) { Qt.callLater(() => view.loadFailed(2)); return; }
        _text = t;
        Qt.callLater(() => view.loaded());
    }
    function writeAdapter() {}
    function setText(t) { _text = t; Qt.callLater(() => view.saved()); }
    onPathChanged: reload()
    property Timer _poll: Timer {
        interval: 250
        repeat: true
        running: view._real && view.watchChanges
        onTriggered: {
            const t = view._read();
            if (t !== null && t !== view._text) view.fileChanged();
        }
    }
}
