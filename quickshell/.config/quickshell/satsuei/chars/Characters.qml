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
        { id: "hana", name: "Hana", ja: "ハナ", builtin: true, file: "Hana.qml" },
        { id: "mochi", name: "Mochi", ja: "もち", builtin: true, file: "Mochi.qml" },
        { id: "kon", name: "Kon", ja: "コン", builtin: true, file: "Kon.qml" },
        { id: "bit", name: "Bit", ja: "ビット", builtin: true, file: "Bit.qml" },
        { id: "yuki", name: "Yuki", ja: "ゆき", builtin: true, file: "Yuki.qml" }
    ]
    readonly property var all: builtins

    function byId(id) { return all.find(c => c.id === id) ?? builtins[0]; }
    readonly property var dancer: byId(Settings.s.dancer)
    readonly property var mascot: byId(Settings.s.mascotChar)

    // the roles: "dancer" (the media card) and "mascot" (the screen edge)
    function key(role) { return role === "mascot" ? "mascotChar" : "dancer"; }
    function set(role, id) {
        if (!all.some(c => c.id === id)) return false;
        Settings.s[key(role)] = id;
        return true;
    }
    function next(role) {
        const i = all.findIndex(c => c.id === Settings.s[key(role)]);
        const c = all[(i + 1) % all.length];
        Settings.s[key(role)] = c.id;
        return c.id;
    }
}
