pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Every window Hyprland has, from `hyprctl clients -j`, read again on its
// window and workspace events: the Dock's running apps and minimized
// windows, Mission Control's and App Exposé's windows. What happens to a
// window is session.lua's GG.* (through gg win), so the binds agree.
Singleton {
    id: root

    property var all: []
    readonly property var regular: all.filter(w => w.mapped && !(w.workspace.name || "").startsWith("special:"))
    readonly property var minimized: all.filter(w => w.workspace.name === "special:minimized")
    readonly property var hidden: all.filter(w => w.workspace.name === "special:hidden")
    // classes with a window anywhere (running), in the order they opened
    readonly property var running: {
        const seen = [];
        for (const w of all.slice().sort((a, b) => a.stableId - b.stableId))
            if (w.class && !seen.includes(w.class)) seen.push(w.class);
        return seen;
    }
    readonly property int activeWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property string activeClass: ""
    property string activeTitle: ""

    // the app's name as its desktop entry gives it ("Files", not org.gnome.Nautilus)
    function appName(cls) {
        const e = DesktopEntries.heuristicLookup(cls);
        return e && e.name ? e.name : cls;
    }
    function onWorkspace(id) { return regular.filter(w => w.workspace.id === id); }
    function ofClass(cls) { return all.filter(w => w.class === cls); }

    function focusWindow(w) { Hyprland.dispatch(`hl.dsp.focus({ window = "address:${w.address}" })`); }
    function restore(w) { Quickshell.execDetached(["gg", "win", "restore", w.address]); }
    // a Dock icon: hidden windows back, a minimized one restored, else the app's first window
    function activate(cls) {
        const ws = ofClass(cls);
        if (ws.some(w => w.workspace.name === "special:hidden")) {
            Quickshell.execDetached(["gg", "win", "unhide", cls]);
            return true;
        }
        const shown = ws.filter(w => !(w.workspace.name || "").startsWith("special:"));
        if (shown.length) { focusWindow(shown[0]); return true; }
        if (ws.length) { restore(ws[0]); return true; }
        return false;
    }

    function refresh() { if (!reader.running) reader.running = true; }
    Process {
        id: reader
        running: true
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.all = JSON.parse(this.text); } catch (e) { /* keep the last list */ }
            }
        }
    }
    Timer { id: soon; interval: 60; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "activewindow") {
                const i = event.data.indexOf(",");
                root.activeClass = event.data.slice(0, i);
                root.activeTitle = event.data.slice(i + 1);
            }
            if (["openwindow", "closewindow", "movewindowv2", "windowtitlev2", "workspacev2", "activewindowv2", "changefloatingmode", "fullscreen"].includes(n))
                soon.restart();
        }
    }
}
