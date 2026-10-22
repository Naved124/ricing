import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// tests/test_satsuei.py: open every surface the shell has so far, through its
// IPC and its singletons, so their bindings and handlers run.
Item {
    property int step: 0
    readonly property var steps: [
        () => IpcRegistry.call("shell", "launcher", ""),
        () => IpcRegistry.call("shell", "search", "=2^10"),
        () => IpcRegistry.call("shell", "search", ":heart"),
        () => IpcRegistry.call("shell", "launcher", "!"),
        () => IpcRegistry.call("shell", "center", ""),
        () => IpcRegistry.call("shell", "studio"),
        () => IpcRegistry.call("shell", "power"),
        () => IpcRegistry.call("shell", "keybinds"),
        () => { Shell.closeAll(); IpcRegistry.call("osd", "trigger", "volume"); },
        () => IpcRegistry.call("osd", "trigger", "brightness"),
        () => IpcRegistry.call("shell", "toast", "dark", "Satsuei is always dark"),
        () => { Shell.recording = true; Shell.caffeine = true; },
        () => console.warn("POKE:" + JSON.stringify({ mode: IpcRegistry.call("mode", "get"),
                                                      stats: JSON.parse(IpcRegistry.call("satsuei", "stats")) })),
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
