pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Every character there is to cast, and who plays each role. The built-ins
// are QML (Rig + Part + Blob); custom ones (step 9) come from
// ~/.config/satsuei/characters/<id>/. A role whose character has gone falls
// back to Hana.
Singleton {
    id: root

    readonly property var builtins: [
        { id: "hana", name: "Hana", ja: "ハナ", builtin: true, file: "Hana.qml" }
    ]
    readonly property var all: builtins

    function byId(id) { return all.find(c => c.id === id) ?? builtins[0]; }
    readonly property var dancer: byId(Settings.s.dancer)
    readonly property var mascot: byId(Settings.s.mascotChar)
}
