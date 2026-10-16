pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Network state from NetworkManager via Quickshell.Networking, plus the
// kernel's own view of the links (/sys/class/net), read once a second. The
// kernel view catches a wired connection NetworkManager's device list misses,
// and gives the live up/down speed for the bar.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired
        && (d.connected || (d.network && d.network.connected))) ?? null
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifi: {
        if (!wifiDevice) return null;
        const nets = wifiDevice.networks.values;
        return nets.find(n => n.connected) ?? null;
    }
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wired: !!wiredDevice || linkWired
    readonly property bool online: wired || !!wifi
    readonly property real strength: wifi ? wifi.signalStrength : 0

    readonly property string label: wired ? "Ethernet" : wifi ? wifi.name : wifiEnabled ? "Not connected" : "Wi-Fi off"
    readonly property string wifiIcon: !wifiEnabled ? "wifi-off"
        : wifi ? (strength > 0.45 ? "wifi" : "wifi-low")
        : "wifi-low"
    // the bar shows whichever link is carrying traffic; wired wins
    readonly property string icon: wired ? "ethernet" : wifi ? wifiIcon : "wifi-off"

    // ── from the kernel ─────────────────────────────────────────────────
    property bool linkWired: false     // a physical, non-wireless link is up
    property real down: 0              // bytes per second, all physical links
    property real up: 0
    property var last: null            // { t, rx, tx } from the previous read

    function setWifi(on) {
        Networking.wifiEnabled = on;
    }

    // "1.2 MB/s", "340 KB/s", "0 B/s"
    function rate(bytes) {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"];
        let v = bytes, i = 0;
        while (v >= 1000 && i < units.length - 1) { v /= 1024; i++; }
        return (v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!links.running) links.running = true
    }

    // one line per physical interface: name, wireless?, operstate, rx, tx
    Process {
        id: links
        command: ["sh", "-c", `
            for d in /sys/class/net/*; do
                [ -e "$d/device" ] || continue
                w=0; { [ -d "$d/wireless" ] || [ -e "$d/phy80211" ]; } && w=1
                printf '%s %s %s %s %s\\n' "\${d##*/}" "$w" "$(cat "$d/operstate")" \\
                    "$(cat "$d/statistics/rx_bytes")" "$(cat "$d/statistics/tx_bytes")"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                let rx = 0, tx = 0, wiredUp = false;
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f.length < 5 || f[2] !== "up") continue;
                    if (f[1] === "0") wiredUp = true;
                    rx += Number(f[3]);
                    tx += Number(f[4]);
                }
                root.linkWired = wiredUp;
                const now = Date.now();
                if (root.last && now > root.last.t) {
                    const dt = (now - root.last.t) / 1000;
                    root.down = Math.max(0, (rx - root.last.rx) / dt);
                    root.up = Math.max(0, (tx - root.last.tx) / dt);
                }
                root.last = { t: now, rx: rx, tx: tx };
            }
        }
    }
}
