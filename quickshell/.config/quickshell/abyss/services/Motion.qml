pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reduced motion: GNOME's "enable animations" turned off (gsettings, followed
// live by one long-lived `gsettings monitor`), or RICE_REDUCED_MOTION=1. The
// reef then moves at 0.45 of its pace, as the mock does.
Singleton {
    id: root

    property bool animations: true
    readonly property bool reduced: Quickshell.env("RICE_REDUCED_MOTION") === "1" || !animations

    function take(text) {
        const v = String(text).trim().split(/\s+/).pop();
        if (v === "true" || v === "false") root.animations = v === "true";
    }
    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]
        stdout: StdioCollector { onStreamFinished: root.take(text) }
    }
    Process {
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "enable-animations"]
        stdout: SplitParser { onRead: line => root.take(line) }
    }
}
