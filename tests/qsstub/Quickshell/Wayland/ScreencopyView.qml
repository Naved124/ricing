// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.
import QtQuick
Item { property var captureSource: null; property bool live: false; property bool paintCursor: false; property bool hasContent: false; function captureFrame() {} }
