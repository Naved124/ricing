import QtQuick
import Quickshell
import qs.common
import qs.services

// tests/test_satsuei.py: the stand-in server sends two notifications at
// start (urgency 1 and 2: normal, critical). The normal one shows for 5.2 s
// and goes; the critical one stays until clicked.
Item {
    function report(tag) {
        console.warn("POKE:" + JSON.stringify({ tag: tag, queue: Notifs.queue.length,
            current: Notifs.current ? Notifs.current.urgency : -1, all: Notifs.all.length }));
    }
    Timer { interval: 300; running: true; onTriggered: parent.report("first") }
    Timer { interval: 6500; running: true; onTriggered: parent.report("second") }
    Timer { interval: 12000; running: true; onTriggered: parent.report("later") }
}
