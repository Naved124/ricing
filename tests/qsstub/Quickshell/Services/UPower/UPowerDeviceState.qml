// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.
pragma Singleton
import QtQuick
QtObject { enum Values { Unknown = 0, Charging = 1, Discharging = 2, Empty = 3, FullyCharged = 4, PendingCharge = 5, PendingDischarge = 6 } }
