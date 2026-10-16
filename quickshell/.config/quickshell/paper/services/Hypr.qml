pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland helpers. Hyprland 0.55+ takes Lua dispatches; older versions take
// the classic syntax. Everything in the shell dispatches through here.
Singleton {
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
