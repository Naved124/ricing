import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// tests/test_satsuei.py: the pass's switches and its pauses, through the
// stats IPC: running, rays switched off (eased to 0), locked (paused, only
// the grade left), unlocked, compositing off (the raw plate).
Item {
    function report(tag) {
        const st = JSON.parse(IpcRegistry.call("satsuei", "stats"));
        console.warn("POKE:" + JSON.stringify({ tag: tag, screens: Object.keys(st).map(k => st[k]) }));
    }
    Timer { interval: 600; running: true; onTriggered: { parent.report("start"); IpcRegistry.call("satsuei", "fx", "rays", false); } }
    Timer { interval: 1200; running: true; onTriggered: { parent.report("no rays"); Shell.locked = true; } }
    Timer { interval: 1800; running: true; onTriggered: { parent.report("locked"); Shell.locked = false; IpcRegistry.call("satsuei", "fx", "rays", true); } }
    Timer { interval: 2400; running: true; onTriggered: { parent.report("unlocked"); IpcRegistry.call("satsuei", "fx", "pass", false); } }
    Timer { interval: 3000; running: true; onTriggered: { parent.report("raw"); IpcRegistry.call("satsuei", "fx", "pass", true); IpcRegistry.call("satsuei", "hour", 17.5); } }
    Timer { interval: 3300; running: true; onTriggered: parent.report("golden") }
}
