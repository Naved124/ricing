pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// The key sheet (Super+/): every bind Hyprland has, from `hyprctl binds -j`,
// grouped by the "Group · what" each is described with, ⌘ ⌥ ⌃ ⇧ for the mods.
Panel {
    id: root

    property var groups: []
    name: "keys"
    paneWidth: Math.min(1100, (screen ? screen.width : 1920) - 120)
    paneHeight: Math.min(760, (screen ? screen.height : 1080) - 120)
    paneX: ((screen ? screen.width : 1920) - paneWidth) / 2
    paneY: ((screen ? screen.height : 1080) - paneHeight) / 2
    onShownChanged: if (shown) reader.running = true

    function mods(m) {
        let s = "";
        if (m & 4) s += "⌃";
        if (m & 8) s += "⌥";
        if (m & 1) s += "⇧";
        if (m & 64) s += "⌘";
        return s;
    }
    Process {
        id: reader
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                let binds = [];
                try { binds = JSON.parse(this.text); } catch (e) { return; }
                const by = {};
                const order = [];
                for (const b of binds) {
                    const d = b.description || "";
                    const i = d.indexOf(" · ");
                    if (i < 0) continue;
                    const g = d.slice(0, i);
                    if (!by[g]) { by[g] = []; order.push(g); }
                    const key = b.key === "Super_L" ? "" : b.key.replace(/^mouse_down$/, "scroll ↓").replace(/^mouse_up$/, "scroll ↑");
                    by[g].push({ keys: root.mods(b.modmask) + " " + key, what: d.slice(i + 3) });
                }
                root.groups = order.map(g => ({ name: g, binds: by[g] }));
            }
        }
    }

    Flickable {
        anchors { fill: parent; margins: 20 }
        contentHeight: flow.implicitHeight
        clip: true
        Flow {
            id: flow
            width: parent.width
            spacing: 24
            Repeater {
                model: root.groups
                delegate: Column {
                    required property var modelData
                    width: (flow.width - 48) / 3
                    spacing: 3
                    Label { text: parent.modelData.name; strong: true; color: Theme.accent }
                    Repeater {
                        model: parent.modelData.binds
                        delegate: Row {
                            required property var modelData
                            spacing: 8
                            Label { width: 110; text: parent.modelData.keys; font.family: Theme.fontMono; font.pixelSize: Theme.smallSize; horizontalAlignment: Text.AlignRight }
                            Label { width: (flow.width - 48) / 3 - 120; text: parent.modelData.what; font.pixelSize: Theme.smallSize; secondary: true }
                        }
                    }
                }
            }
        }
    }
}
