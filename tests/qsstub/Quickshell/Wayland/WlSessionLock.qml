// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
import Quickshell
Item {
    id: root
    property bool locked: false
    property bool secure: false
    default property Component surface
    property var surfaces: []
    onLockedChanged: {
        if (locked && surface) {
            for (const s of Quickshell.screens) surfaces.push(surface.createObject(root, { screen: s }));
            secure = true;
        } else { for (const s of surfaces) s.destroy(); surfaces = []; secure = false; }
    }
}
