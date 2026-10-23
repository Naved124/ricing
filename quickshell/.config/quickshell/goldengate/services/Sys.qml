pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and the root disk, for the desk's system card (and Paper's
// bar). One long-lived reader every 2 s (/proc files report no size, which
// file readers that trust the size get wrong), restarted if it ever exits:
//   cpu …       the first line of /proc/stat: the share not idle since last time
//   mem T A     MemTotal and MemAvailable (kB): used is what isn't available
//   disk S U A  df's size, used and available bytes for /, every 30 s
// The same file sits in paper/services and nacre/services; the tests keep the
// copies identical.
Singleton {
    id: root

    property real cpu: 0            // 0..1
    property real mem: 0            // 0..1
    property real memUsed: 0        // bytes
    property real memTotal: 0
    property real diskUsed: 0
    property real diskFree: 0
    property real diskTotal: 0
    readonly property real disk: diskTotal > 0 ? diskUsed / diskTotal : 0
    property var last: null         // { idle, total }

    // "212 GB", "7.1 GB", "940 MB": one decimal under 10, decimal units like df -H
    function fmt(bytes) {
        const units = ["B", "kB", "MB", "GB", "TB"];
        let v = Math.max(0, bytes), i = 0;
        while (v >= 1000 && i < units.length - 1) { v /= 1000; i++; }
        return `${v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)} ${units[i]}`;
    }

    function sample(line) {
        const f = line.trim().split(/\s+/);
        const n = f.slice(1).map(Number);
        if (f[0] === "cpu") {
            if (n.length < 4 || n.some(isNaN)) return;
            const idle = n[3] + (n[4] || 0);          // idle + iowait
            const total = n.reduce((a, b) => a + b, 0);
            if (root.last && total > root.last.total)
                root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.last.idle) / (total - root.last.total)));
            root.last = { idle: idle, total: total };
        } else if (f[0] === "mem" && n.length === 2 && n[0] > 0) {
            root.memTotal = n[0] * 1024;
            root.memUsed = Math.max(0, n[0] - n[1]) * 1024;
            root.mem = root.memUsed / root.memTotal;
        } else if (f[0] === "disk" && n.length === 3 && n[0] > 0) {
            root.diskTotal = n[0];
            root.diskUsed = n[1];
            root.diskFree = n[2];
        }
    }

    Process {
        id: reader
        running: true
        command: ["sh", "-c", "i=0; while :; do "
            + "head -n1 /proc/stat; "
            + "awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print \"mem\", t, a}' /proc/meminfo; "
            + "[ $((i % 15)) -eq 0 ] && df -B1 --output=size,used,avail / | awk 'NR==2{print \"disk\", $1, $2, $3}'; "
            + "i=$((i + 1)); sleep 2; done"]
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
