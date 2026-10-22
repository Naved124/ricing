import QtQuick
import Quickshell
import Quickshell.Io

// Light or dark, for the whole shell. Theme.qml holds one of these and mixes
// every colour between the light and dark palettes by `k` (0 light, 1 dark).
//
// The mode lives in ~/.local/state/rice/mode ("light" or "dark"), which
// `rice mode` writes. It is read synchronously before the first frame, so a
// shell started at night never flashes light. After that the file is
// watched, and the `mode` IPC lets `rice mode` drive the change directly:
//   jump  k at once (a transition overlay is covering the screen)
//   set   crossfade over 600 ms
//   fade  crossfade over a given time (the fallback when there's no overlay)
//
// A rice with one mode (Abyss) sets `only: "dark"`: it stays there whatever
// the file says, and answers `get` with it.
//
// The same file sits in every shell (paper/common, nacre, rice, abyss, satsuei/common); the
// tests keep the copies identical.
Scope {
    id: mode

    property var curve: [0.2, 0.9, 0.2, 1.0, 1, 1]   // Easing.BezierSpline control points
    property string only: ""                          // "dark" for a dark-only rice
    property bool dark: only === "dark"
    property real k: only === "dark" ? 1 : 0
    property bool started: false
    // auto mode, and what it does next ("auto · light at 06:41", "held until
    // 18:02 (then auto)"), from `rice mode status`; re-read when the mode or
    // its source changes
    property bool auto: false
    property string next: ""

    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                                   + "/rice/mode"

    function isDark(text) { return String(text ?? "").trim() === "dark"; }

    function jump(m) {
        if (only)
            m = only;
        fade.stop();
        dark = isDark(m);
        k = dark ? 1 : 0;
    }

    function set(m, ms) {
        if (only)
            m = only;
        const to = isDark(m) ? 1 : 0;
        dark = to === 1;
        if (k === to && !fade.running)
            return;
        fade.stop();
        fade.from = k;
        fade.to = to;
        fade.duration = ms ?? 600;
        fade.start();
    }

    // a and b are colours or palette "#rrggbb(aa)" strings; mixed per channel,
    // alpha too, by t (k unless given). A curve that overshoots (Paper's drop)
    // bounces the motion, not the colours, so t stays within 0..1.
    function mix(a, b, t) {
        const x = rgba(a), y = rgba(b), f = Math.max(0, Math.min(1, t ?? k));
        return Qt.rgba(x.r + (y.r - x.r) * f, x.g + (y.g - x.g) * f,
                       x.b + (y.b - x.b) * f, x.a + (y.a - x.a) * f);
    }
    function blend(a, b, t) { return a + (b - a) * Math.max(0, Math.min(1, t ?? k)); }
    function rgba(v) {
        if (typeof v !== "string")
            return v;
        const n = parseInt(v.slice(1, 7), 16);
        const a = v.length > 7 ? parseInt(v.slice(7, 9), 16) / 255 : 1;
        return { r: (n >> 16 & 255) / 255, g: (n >> 8 & 255) / 255, b: (n & 255) / 255, a: a };
    }

    // light → dark → auto → light, for a control centre's tile; if auto
    // can't start (a bad location in mode.toml), dark goes straight to light
    // rather than sticking
    function cycle() {
        Quickshell.execDetached(["sh", "-c", auto ? "rice mode auto off && rice mode light"
                                                  : dark ? "rice mode auto || rice mode light" : "rice mode dark"]);
    }
    function refreshStatus() { status.running = true; }

    Process {
        id: status
        command: ["rice", "mode", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" · ");
                mode.auto = parts.length > 1 && parts[1] !== "manual";
                mode.next = mode.auto ? parts.slice(1).join(" · ") : "";
            }
        }
    }
    FileView {
        path: mode.path + "-source"
        watchChanges: true
        printErrors: false
        onFileChanged: mode.refreshStatus()
    }
    Timer {
        interval: 60000             // a held choice runs out, the next switch nears
        running: mode.auto
        repeat: true
        onTriggered: mode.refreshStatus()
    }

    NumberAnimation {
        id: fade
        target: mode
        property: "k"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: mode.curve
    }

    FileView {
        id: file
        path: mode.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            mode.refreshStatus();
            if (mode.started)
                mode.set(text(), 600);
            else
                mode.jump(text());
        }
    }

    IpcHandler {
        target: "mode"
        function set(m: string): void { mode.set(m, 600); }
        function jump(m: string): void { mode.jump(m); }
        function fade(m: string, ms: int): void { mode.set(m, ms); }
        // `rice mode` does the work, so the state file stays the one source
        function toggle(): void { Quickshell.execDetached(["rice", "mode", "toggle"]); }
        function get(): string { return mode.dark ? "dark" : "light"; }
    }

    Component.onCompleted: {
        jump(file.text());
        started = true;
    }
}
