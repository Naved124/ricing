import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// tests/test_abyss.py: open every surface the shell has, through its IPC and
// its singletons, so their bindings and handlers run; report what the IPC
// answered.
Item {
    property int step: 0
    readonly property var steps: [
        () => IpcRegistry.call("shell", "launcher", ""),
        () => IpcRegistry.call("shell", "search", "=2^10"),
        () => IpcRegistry.call("shell", "search", ":heart"),
        () => IpcRegistry.call("shell", "launcher", "!"),
        () => IpcRegistry.call("shell", "center", "calendar"),
        () => { IpcRegistry.call("reef", "toggleInteractive"); IpcRegistry.call("reef", "toggleStats"); },
        () => IpcRegistry.call("shell", "power"),
        () => IpcRegistry.call("shell", "keybinds"),
        () => Shell.toggleIsland("DP-1"),
        () => { Shell.closeAll(); IpcRegistry.call("osd", "trigger", "volume"); },
        () => IpcRegistry.call("osd", "trigger", "brightness"),
        () => IpcRegistry.call("shell", "toast", "dark", "Abyss is always dark"),
        () => { IpcRegistry.call("reef", "notify"); IpcRegistry.call("reef", "disturb", 400, 300, 1); },
        () => { Shell.recording = true; Shell.caffeine = true; },
        () => IpcRegistry.call("lock", "lock"),
        () => console.warn("POKE:" + JSON.stringify({ mode: IpcRegistry.call("mode", "get"),
                                                      locked: IpcRegistry.call("lock", "isLocked"),
                                                      stats: JSON.parse(IpcRegistry.call("reef", "stats")) })),
    ]
    Timer {
        interval: 350
        repeat: true
        running: true
        onTriggered: {
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step]();
            parent.step++;
        }
    }
}
