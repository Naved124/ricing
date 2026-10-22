pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.services

// The plate and its pass as the wallpaper, one per screen, on the background
// layer. The pass's time moves at 30 fps from a Timer; between ticks nothing
// redraws. It pauses (the plate keeps its grade, nothing else moves) while
//   · a window is fullscreen on this screen
//   · the battery is under 30% and discharging
//   · the session is locked (the lock draws its own)
// A new plate fades in over the old one; the selector's preview does too.
// Inside every window on this screen's workspace the plate is frosted (its
// soft map), pass or no pass: see-through windows are glass over it whatever
// Hyprland's blur does (it drew none behind GTK windows).
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool fullscreen: Hypr.fullscreenOn(monitor)
    readonly property bool lowBattery: Battery.present && Battery.onBattery && !Battery.charging && Battery.level < 0.3
    readonly property bool paused: fullscreen || lowBattery || Shell.locked
    readonly property string why: fullscreen ? "paused: fullscreen" : Shell.locked ? "paused: locked"
        : lowBattery ? `paused: battery ${Math.round(Battery.level * 100)}%` : "running"
    readonly property bool raw: !Settings.s.pass || Shell.comparing

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "satsuei-plate"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: Theme.ink

    // ── each effect eases between 0 and 1 over 250 ms ─────────────────────
    component Ease: NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    readonly property bool moving: !paused && !raw
    property real bloom: moving && Settings.s.bloom ? 1 : 0
    property real rays: moving && Settings.s.rays ? 1 : 0
    property real motes: moving && Settings.s.motes && !Motion.reduced ? 1 : 0
    property real grain: moving && Settings.s.grain ? 1 : 0
    property real grade: !raw && Settings.s.grade ? 1 : 0
    property real pass: raw ? 0 : 1
    property real frost: Settings.s.frost ? 1 : 0
    Behavior on bloom { Ease {} }
    Behavior on rays { Ease {} }
    Behavior on motes { Ease {} }
    Behavior on grain { Ease {} }
    Behavior on grade { Ease {} }
    Behavior on pass { Ease {} }
    Behavior on frost { Ease {} }

    // the windows on this screen's workspace, in its px, for the frost
    readonly property var glass: {
        const ws = monitor?.activeWorkspace?.id ?? -1;
        const ox = screen?.x ?? 0, oy = screen?.y ?? 0;
        return Windows.onWorkspace(ws).map(w => ({ x: w.x - ox, y: w.y - oy, w: w.w, h: w.h }));
    }

    // ── time: 30 fps while anything moves ─────────────────────────────────
    property real time: 0
    property int frames: 0
    property real fps: 0
    readonly property bool ticking: !paused && (rays + motes + grain > 0.001 || Math.abs(par.x - parTarget.x) > 1e-5
                                               || Math.abs(par.y - parTarget.y) > 1e-5)
    Timer {
        id: tick
        interval: 33
        repeat: true
        running: win.ticking
        property double last: 0
        property double fpsAt: 0
        onTriggered: {
            const now = Date.now();
            const dt = last ? Math.min(0.1, (now - last) / 1000) : 1 / 30;
            last = now;
            if (!Motion.reduced) win.time += dt;
            // the parallax eases toward the pointer
            const k = Math.min(1, dt * 2.5);
            win.par = Qt.point(win.par.x + (win.parTarget.x - win.par.x) * k,
                               win.par.y + (win.parTarget.y - win.par.y) * k);
            win.frames++;
            if (now - fpsAt >= 1000) {
                win.fps = win.frames * 1000 / (now - fpsAt || 1);
                win.frames = 0;
                fpsAt = now;
            }
        }
        onRunningChanged: if (!running) { last = 0; win.fps = 0; }
    }

    // ── parallax: at most 0.6%, following the pointer over the desktop ────
    property point par: Qt.point(0, 0)
    property point parTarget: Qt.point(0, 0)
    HoverHandler {
        enabled: Settings.s.parallax && !Motion.reduced
        onPointChanged: {
            const p = point.position;
            win.parTarget = Qt.point((p.x / win.width - 0.5) * -0.006, (p.y / win.height - 0.5) * -0.006);
        }
    }

    // ── the plate, faded across on a change ───────────────────────────────
    property int front: 0
    function load() {
        const pass = front === 0 ? b : a;
        pass.source = Theme.plate;
        pass.bloomSource = Theme.previewing ? "" : Theme.bloomMap;
        pass.softSource = Theme.previewing ? "" : Theme.softMap;
        pass.animated = Theme.animated;
        pass.plateSize = Theme.plateSize;
        front = 1 - front;
    }
    Connections {
        target: Theme
        function onPlateChanged() { win.load(); }
        function onBloomMapChanged() { if (!Theme.previewing) win.load(); }
    }
    Component.onCompleted: {
        Plates.add(screen?.name ?? "", win);
        a.source = Theme.plate;
        a.bloomSource = Theme.bloomMap;
        a.softSource = Theme.softMap;
        a.animated = Theme.animated;
        a.plateSize = Theme.plateSize;
    }

    component Layer: Pass {
        anchors.fill: parent
        light: Qt.point(Theme.lightX, Theme.lightY)
        parallax: win.par
        time: win.time
        bloom: win.bloom
        rays: win.rays
        motes: win.motes
        grain: win.grain
        grade: win.grade
        pass: win.pass
        frost: win.frost
        windows: win.glass
        expo: Settings.s.expo
        playing: !win.paused
        // the one in front fades in once it has loaded; the one behind stays
        // until it's covered, then stops drawing
        property bool isFront: false
        property Pass other
        opacity: isFront ? (ready ? 1 : 0) : 1
        visible: isFront || other.opacity < 1 || !other.ready
        z: isFront ? 1 : 0
        Behavior on opacity {
            enabled: a.ready && b.ready
            NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
        }
    }
    Layer { id: a; isFront: win.front === 0; other: b }
    Layer { id: b; isFront: win.front === 1; other: a }

    // ── picking the light source (the Satsuei panel) ──────────────────────
    MouseArea {
        anchors.fill: parent
        enabled: Shell.pickingLight
        visible: enabled
        cursorShape: Qt.CrossCursor
        onClicked: mouse => {
            const W = win.width, H = win.height, I = Theme.plateSize;
            const s = Math.max(W / I.width, H / I.height) * 1.04;
            const x = ((mouse.x - W / 2) / s + I.width / 2) / I.width - win.par.x;
            const y = ((mouse.y - H / 2) / s + I.height / 2) / I.height - win.par.y;
            Quickshell.execDetached(["satsuei-wall", "light", x.toFixed(4), y.toFixed(4)]);
            Shell.pickingLight = false;
        }
    }
    Crosshair {
        anchors.fill: parent
        visible: Shell.pickingLight
    }

    // what `qs -c satsuei ipc call satsuei stats` reports for this screen
    function stats() {
        return { screen: screen?.name ?? "", state: why, fps: +fps.toFixed(1), ticking: ticking,
                 plate: Theme.plateName, animated: Theme.animated, raw: raw,
                 effects: { bloom: +bloom.toFixed(2), rays: +rays.toFixed(2), motes: +motes.toFixed(2),
                            grain: +grain.toFixed(2), grade: +grade.toFixed(2) },
                 grade: { hour: Theme.grade.fmt(Theme.grade.hour), phase: Theme.grade.phase },
                 size: [width, height], rays: [Math.round(width / 8), Math.round(height / 8)] };
    }
    Component.onDestruction: Plates.remove(screen?.name ?? "", win)
}
