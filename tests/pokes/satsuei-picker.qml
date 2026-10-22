import QtQuick
import Quickshell
import Quickshell.Io
import qs.chars
import qs.common
import qs.services

// tests/test_satsuei.py: open the Cast picker for the mascot through IPC, cast
// the next card with the keys' function, switch role, close it.
Item {
    property int step: 0
    readonly property var steps: [
        () => IpcRegistry.call("satsuei", "cast", "mascot"),
        () => console.warn("POKE:" + JSON.stringify({ tag: "open", open: Shell.castOpen, role: Shell.castRole })),
        () => { Characters.set("mascot", "kon"); Shell.castRole = "dancer"; },
        () => { Shell.toggleCast(); },
        () => console.warn("POKE:" + JSON.stringify({ tag: "closed", open: Shell.castOpen, mascot: Characters.mascot.id })),
    ]
    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step]();
            parent.step++;
        }
    }
}
