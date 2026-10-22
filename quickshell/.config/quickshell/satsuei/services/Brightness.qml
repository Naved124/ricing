pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness through brightnessctl. The backlight has no change
// notification, so it is re-read four times a second (a tiny sysfs read).
Singleton {
    id: root

    property real level: 0          // 0..1
    property bool available: false
    property string device: ""

    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        level = v;
        setter.command = ["brightnessctl", "-q", "set", Math.round(v * 100) + "%"];
        setter.running = true;
    }

    Process {
        id: probe
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent,max
                const f = text.trim().split(",");
                if (f.length >= 5) {
                    root.device = f[0];
                    root.available = true;
                    root.level = parseInt(f[2]) / parseInt(f[4]);
                    maxFile.max = parseInt(f[4]);
                }
            }
        }
    }

    FileView {
        id: maxFile
        property int max: 1
        path: root.available ? `/sys/class/backlight/${root.device}/brightness` : ""
        blockLoading: true
        onLoaded: {
            const v = parseInt(text()) / max;
            if (!isNaN(v) && Math.abs(v - root.level) > 0.004) root.level = v;
        }
    }

    Timer {
        running: root.available
        interval: 250
        repeat: true
        onTriggered: maxFile.reload()
    }

    Process {
        id: setter
    }
}
