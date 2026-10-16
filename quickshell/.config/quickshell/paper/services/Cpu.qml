pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU use from /proc/stat, every 2 s: the share of time not idle since the
// last read. One long-lived reader (/proc files report no size, which file
// readers that trust the size get wrong), restarted if it ever exits.
Singleton {
    id: root

    property real usage: 0          // 0..1
    property var last: null         // { idle, total }

    function sample(line) {
        const f = line.trim().split(/\s+/).slice(1).map(Number);
        if (f.length < 4 || f.some(isNaN)) return;
        const idle = f[3] + (f[4] || 0);          // idle + iowait
        const total = f.reduce((a, b) => a + b, 0);
        if (root.last && total > root.last.total)
            root.usage = Math.max(0, Math.min(1, 1 - (idle - root.last.idle) / (total - root.last.total)));
        root.last = { idle: idle, total: total };
    }

    Process {
        id: reader
        running: true
        command: ["sh", "-c", "while :; do head -n1 /proc/stat; sleep 2; done"]
        stdout: SplitParser {
            onRead: line => root.sample(line)
        }
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 2000
        onTriggered: reader.running = true
    }
}
