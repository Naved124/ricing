pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Where the windows are, for the plate's frost: `hyprctl clients -j`, read
// again whenever Hyprland says a window opened, closed, moved, floated or
// went fullscreen, or a workspace changed (twice: at once, and once the
// animation has settled). Only the plate reads this.
Singleton {
    id: root

    // [{ x, y, w, h, ws, fullscreen }] in layout px, mapped and on a normal workspace
    property var list: []

    function onWorkspace(id) { return list.filter(w => w.ws === id && !w.fullscreen); }

    readonly property var events: ["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode",
        "fullscreen", "workspace", "workspacev2", "focusedmon", "moveworkspace", "activespecial", "pin",
        "minimized", "activewindowv2", "configreloaded", "monitoradded", "monitorremoved"]
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.events.includes(event.name)) {
                now.restart();
                settled.restart();
            }
        }
    }
    Timer { id: now; interval: 30; onTriggered: root.refresh() }
    Timer { id: settled; interval: 650; onTriggered: root.refresh() }

    property bool again: false
    function refresh() {
        if (read.running) again = true;
        else read.running = true;
    }
    Process {
        id: read
        running: true
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.list = JSON.parse(text)
                        .filter(c => c.mapped && !c.hidden && c.workspace && c.workspace.id > 0)
                        .map(c => ({ x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1], ws: c.workspace.id,
                                     fullscreen: !!c.fullscreen }));
                } catch (e) {}
            }
        }
        onExited: if (root.again) { root.again = false; running = true; }
    }
}
