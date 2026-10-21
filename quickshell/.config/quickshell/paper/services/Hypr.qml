pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Hyprland helpers. Hyprland 0.55+ takes Lua dispatches; older versions take
// the classic syntax. Everything in the shell dispatches through here.
Singleton {
    id: root

    // the focused window, straight from Hyprland's events: `activewindow`
    // (class and title, empty when nothing is focused), `activewindowv2` (its
    // address) and `windowtitlev2` (a title changing). Hyprland.activeToplevel
    // can stay on the previous window, so the bars read these instead. Read
    // once from `hyprctl activewindow -j` at start.
    property string activeTitle: ""
    property string activeClass: ""
    property string activeAddress: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const data = event.data ?? "";
            const cut = data.indexOf(",");
            if (event.name === "activewindow") {
                root.activeClass = cut < 0 ? "" : data.slice(0, cut);
                root.activeTitle = cut < 0 ? "" : data.slice(cut + 1);
            } else if (event.name === "activewindowv2") {
                root.activeAddress = data;
            } else if (event.name === "windowtitlev2" && cut > 0 && data.slice(0, cut) === root.activeAddress) {
                root.activeTitle = data.slice(cut + 1);
            }
        }
    }
    Process {
        running: true
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text);
                    root.activeTitle = w.title ?? "";
                    root.activeClass = w.class ?? "";
                    root.activeAddress = String(w.address ?? "").replace(/^0x/, "");
                } catch (e) {}
            }
        }
    }

    // the screen of the monitor Hyprland has focused (popups, OSDs, launcher)
    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function dispatch(lua, classic) {
        Hyprland.dispatch(Hyprland.usingLua ? lua : classic);
    }

    function focusWorkspace(id) {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`, `workspace ${id}`);
    }

    function cycleWorkspace(step) {
        const rel = step > 0 ? `e+${step}` : `e${step}`;
        dispatch(`hl.dsp.focus({ workspace = "${rel}" })`, `workspace ${rel}`);
    }

    function monitorFor(screen) {
        return screen ? Hyprland.monitorFor(screen) : null;
    }

    function workspace(id) {
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; i++)
            if (all[i].id === id) return all[i];
        return null;
    }

    // a fullscreen window on this monitor's active workspace
    function fullscreenOn(monitor) {
        return !!(monitor && monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen);
    }
}
