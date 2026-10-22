import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// tests/test_abyss.py: lock, unlock with the password, and check the
// wallpaper's reefs run again. The test adds a `testUnlock` IPC function to a
// scratch copy of the shell's Lock.qml (the shipped one has no way in but the
// password field).
Item {
    function report(tag) {
        const st = JSON.parse(IpcRegistry.call("reef", "stats"));
        console.warn("POKE:" + JSON.stringify({ tag: tag, locked: Shell.locked,
            reefs: Object.keys(st).map(k => ({ running: st[k].running, throttle: st[k].throttle, fps: st[k].fps })) }));
    }
    Timer { interval: 1500; running: true; onTriggered: { parent.report("before"); IpcRegistry.call("lock", "lock"); } }
    Timer { interval: 3000; running: true; onTriggered: { parent.report("locked"); IpcRegistry.call("lock", "testUnlock", "right"); } }
    Timer { interval: 6500; running: true; onTriggered: parent.report("after") }
}
