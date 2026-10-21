// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

pragma Singleton
import QtQuick
import Quickshell
QtObject {
    property QtObject defaultAdapter: QtObject { property bool enabled: true; property bool discovering: false; property string name: "hci0" }
    property QsObjectModel adapters: QsObjectModel {}
    property QsObjectModel devices: QsObjectModel {}
}
