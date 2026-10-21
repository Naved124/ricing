pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// What the chooser knows about: every rice (with its rendered meta.json),
// the active one, and the light/dark mode. All of it comes from `rice json`, so the
// script stays the single source of truth.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("RICE_DIR") || Quickshell.env("HOME") + "/.config/rices"
    property var list: []            // [{ name, card, preview, meta }]
    property string current: ""
    property bool auto: false        // auto mode: light and dark follow the sun
    property string mode: "light"
    property string next: ""         // "light at 06:41", "held until …", or ""
    readonly property var active: list.find(r => r.name === current) ?? null

    function find(name) {
        return list.find(r => r.name === name) ?? null;
    }

    function refresh() {
        proc.running = true;
    }

    function apply(name) {
        Quickshell.execDetached(["rice", name]);
    }

    // the footer's pill: light, dark (auto off), or auto
    function setMode(m) {
        if (m === "auto") { setAuto(true); return; }
        auto = false;
        mode = m;
        Quickshell.execDetached(["sh", "-c", `rice mode auto off; rice mode ${m}; qs -c rice ipc call rice reload`]);
    }

    function setAuto(on) {
        auto = on;      // optimistic; refresh() confirms
        Quickshell.execDetached(["sh", "-c", `rice mode auto${on ? "" : " off"}; qs -c rice ipc call rice reload`]);
    }

    Process {
        id: proc
        running: true
        command: ["rice", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.list = d.rices ?? [];
                    root.current = d.current ?? "";
                    root.auto = !!d.mode_auto;
                    root.mode = d.mode ?? "light";
                    root.next = d.mode_next ?? "";
                } catch (e) {
                    console.warn("rice json:", e);
                }
            }
        }
    }
}
