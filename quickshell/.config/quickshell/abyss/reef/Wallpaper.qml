pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// The reef as the wallpaper, one per screen, on the background layer: it
// feels the pointer only where no window covers it, and never the keyboard.
// Each screen grows its own reef (its own seed). The desktop reaches it:
//   a workspace switch    a current sweeps across in the move's direction
//   a notification        the jelly nearest it flares (Reefs.notify)
//   music                 bass onsets kick it (Pulse), or it breathes
//   the shell             disturbances where cards land, the launcher opens…
// and decides how hard it works:
//   stopped    no frames, no simulation: a fullscreen window on this
//              screen, or the session locked (the lock has its own reef).
//              Not DPMS: Hyprland's monitor info can stay stale after the
//              screen wakes, which froze the reef everywhere; hypridle locks
//              before it turns the screen off, and a dark screen sends no
//              frame callbacks, so nothing is drawn then anyway.
//   reduced    15 fps, half the plankton, no bloom: tiled windows cover 92%
//              of the screen, or the battery is under 30% (reduce_on_battery)
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int index: Math.max(0, Quickshell.screens.indexOf(screen))

    // ── throttling ─────────────────────────────────────────────────────────
    property real coverage: 0                 // of this screen, by windows on its workspace
    readonly property bool fullscreen: Hypr.fullscreenOn(monitor)
    readonly property bool stopped: fullscreen || Shell.locked
    readonly property bool lowBattery: Config.reduceOnBattery && Battery.onBattery && Battery.present && Battery.level < 0.3
    readonly property bool reduced: coverage >= 0.92 || lowBattery
    readonly property string throttle: fullscreen ? "stopped: fullscreen" : Shell.locked ? "stopped: locked"
        : coverage >= 0.92 ? `reduced: windows cover ${Math.round(coverage * 100)}%`
        : lowBattery ? `reduced: battery ${Math.round(Battery.level * 100)}%` : "full"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "abyss-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: Theme.abyss

    Reef {
        id: reef
        anchors.fill: parent
        seed: 20261021 + win.index * 7919
        colors: Theme.reefColors
        kelpColor: Theme.c("kelp")
        hues: Theme.reefHues
        waterTop: Theme.waterTop
        waterMid: Theme.waterMid
        waterBottom: Theme.waterBottom
        still: "file://" + Quickshell.env("HOME") + "/.config/rices/abyss/assets/wall-static.png"
        fps: Config.fps
        sceneScale: Config.scale
        plankton: Config.plankton
        fish: Config.fish
        jellies: Config.jellies
        interactive: Config.interactive && Shell.reefInteractive
        reducedMotion: Motion.reduced
        running: !win.stopped
        reduced: win.reduced
        dpr: win.screen?.devicePixelRatio ?? 1
        breathing: Config.musicReact && Pulse.breathing
        name: win.screen?.name ?? ""
        throttle: win.throttle
        coverage: win.coverage
        Component.onCompleted: Reefs.add(win.screen.name, reef)
        Component.onDestruction: Reefs.remove(win.screen.name, reef)
    }

    // ── workspaces: a current in the direction of the move ────────────────
    property int lastWorkspace: monitor?.activeWorkspace?.id ?? 0
    Connections {
        target: win.monitor
        function onActiveWorkspaceChanged() {
            const id = win.monitor?.activeWorkspace?.id ?? 0;
            if (id > 0 && win.lastWorkspace > 0 && id !== win.lastWorkspace)
                reef.switchWs(id > win.lastWorkspace ? 1 : -1);
            win.lastWorkspace = id;
            coverageLater.restart();
        }
    }

    // ── music ─────────────────────────────────────────────────────────────
    Connections {
        target: Pulse
        enabled: Config.musicReact
        function onKicked() { reef.kick(); }
    }

    // ── how much of the screen windows cover ──────────────────────────────
    // Tiled windows on this screen's workspace, from Hyprland's clients, on
    // a 48 × 27 grid; refreshed shortly after a window opens, closes, moves
    // or changes, and every few seconds while the reef runs (a resize has no
    // event).
    function measure() {
        const ws = monitor?.activeWorkspace;
        const sx = screen.x, sy = screen.y, sw = screen.width, sh = screen.height;
        if (!ws || sw <= 0 || sh <= 0) { coverage = 0; return; }
        const rects = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.at || !o.size || o.hidden || o.mapped === false) continue;
            if ((o.workspace?.id ?? t.workspace?.id) !== ws.id) continue;
            rects.push([o.at[0] - sx, o.at[1] - sy, o.size[0], o.size[1]]);
        }
        let hit = 0;
        const cols = 48, rows = 27;
        for (let j = 0; j < rows; j++) {
            const y = (j + 0.5) / rows * sh;
            for (let i = 0; i < cols; i++) {
                const x = (i + 0.5) / cols * sw;
                for (const r of rects)
                    if (x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3]) { hit++; break; }
            }
        }
        coverage = hit / (cols * rows);
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "workspacev2",
                 "fullscreen", "activewindowv2", "moveworkspacev2", "focusedmonv2"].includes(event.name))
                coverageLater.restart();
        }
    }
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { coverageLater.restart(); }
    }
    Timer {
        id: coverageLater
        interval: 250
        onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshMonitors(); settle.restart(); }
    }
    // the refresh answers asynchronously; measure once it has
    Timer { id: settle; interval: 120; onTriggered: win.measure() }
    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshMonitors(); settle.restart(); }
    }
}
