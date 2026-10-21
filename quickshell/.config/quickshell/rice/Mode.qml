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
// The same file sits in every shell (paper/common, nacre, rice); the tests
// keep the copies identical.
Scope {
    id: mode

    property var curve: [0.2, 0.9, 0.2, 1.0, 1, 1]   // Easing.BezierSpline control points
    property bool dark: false
    property real k: 0
    property bool started: false

    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                                   + "/rice/mode"

    function isDark(text) { return String(text ?? "").trim() === "dark"; }

    function jump(m) {
        fade.stop();
        dark = isDark(m);
        k = dark ? 1 : 0;
    }

    function set(m, ms) {
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
