// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
Item {
    id: root
    property var model: []
    default property Component delegate
    property var instances: []
    Instantiator {
        model: root.model
        delegate: root.delegate
        onObjectAdded: (i, o) => { root.instances = root.instances.concat([o]); }
        onObjectRemoved: (i, o) => root.instances = root.instances.filter(x => x !== o)
    }
}
