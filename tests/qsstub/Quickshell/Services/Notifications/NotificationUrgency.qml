// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.
pragma Singleton
import QtQuick
QtObject { enum Values { Low = 0, Normal = 1, Critical = 2 } }
