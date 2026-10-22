import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// tests/test_satsuei.py: lock, try a wrong password and the right one, and
// check the plates' passes stop while locked and run again after. The test
// adds a `testUnlock` IPC function to a scratch copy of lock/Lock.qml (the
// shipped one has no way in but the password field).
Item {
    function report(tag) {
        const st = JSON.parse(IpcRegistry.call("satsuei", "stats"));
        console.warn("POKE:" + JSON.stringify({ tag: tag, locked: Shell.locked,
            plates: Object.keys(st).map(k => st[k].state) }));
    }
    Timer { interval: 1200; running: true; onTriggered: { parent.report("before"); IpcRegistry.call("lock", "lock"); } }
    Timer { interval: 2200; running: true; onTriggered: { parent.report("locked"); IpcRegistry.call("lock", "testUnlock", "wrong"); } }
    Timer { interval: 3000; running: true; onTriggered: { parent.report("wrong"); IpcRegistry.call("lock", "testUnlock", "right"); } }
    Timer { interval: 4500; running: true; onTriggered: parent.report("after") }
}
