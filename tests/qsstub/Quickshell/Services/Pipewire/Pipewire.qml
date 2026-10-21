// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

pragma Singleton
import QtQuick
QtObject {
    property PwNode defaultAudioSink: PwNode {}
    property PwNode defaultAudioSource: PwNode { isSink: false; name: "mic" }
    property bool ready: true
    property QtObject nodes: QtObject { property var values: [] }
}
