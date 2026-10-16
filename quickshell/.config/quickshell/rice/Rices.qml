pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// What the chooser knows about: every rice (with its rendered meta.json),
// the active one, and auto mode. All of it comes from `rice json`, so the
// script stays the single source of truth.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("RICE_DIR") || Quickshell.env("HOME") + "/.config/rices"
    property var list: []            // [{ name, card, preview, meta }]
    property string current: ""
    property bool auto: false
    property string schedule: ""
    readonly property var active: list.find(r => r.name === current) ?? null

    // a role colour of the active rice, for the chooser's own chrome
    function role(name, fallback) {
        return active?.meta?.roles?.[name] ?? fallback;
    }

    function find(name) {
        return list.find(r => r.name === name) ?? null;
    }

    function refresh() {
        proc.running = true;
    }

    function apply(name) {
        Quickshell.execDetached(["rice", name]);
    }

    function setAuto(on) {
        auto = on;      // optimistic; refresh() confirms
        Quickshell.execDetached(["sh", "-c", `rice auto ${on ? "on" : "off"}; qs -c rice ipc call rice reload`]);
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
                    root.auto = !!d.auto;
                    root.schedule = d.schedule ?? "";
                } catch (e) {
                    console.warn("rice json:", e);
                }
            }
        }
    }
}
