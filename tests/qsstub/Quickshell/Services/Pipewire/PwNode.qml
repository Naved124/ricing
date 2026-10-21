// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property bool ready: true
    property string name: "speakers"
    property string description: "Speakers"
    property string nickname: ""
    property bool isSink: true
    property bool isStream: false
    property QtObject audio: QtObject { property real volume: 0.6; property bool muted: false }
    property var properties: ({})
}
