pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Satsuei's colours: the cel layer takes every one of them from the plate.
// `satsuei-wall set <picture>` writes ~/.local/state/satsuei/theme.json; this
// watches it, and each token fades to its new value over 600 ms, so a new
// wallpaper crossfades the whole shell into its look. Before any wallpaper is
// set, the seed (rices/satsuei/seed/, the mock's plate) stands in.
//
// The wallpaper selector previews a picture's tokens with preview() and
// drops them with endPreview(); nothing is written until it's applied.
// There are no colour literals here or anywhere in the shell (the lint test):
// fixed values (type, shape, motion, the characters' skin) are in Style.qml,
// generated from palette.toml.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/satsuei"
    readonly property string seedDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/rices/satsuei/seed"

    // the tokens as read, and what's on screen (a preview wins). On a change
    // `was` keeps the tokens being left and `f` runs 0 → 1 over 600 ms; every
    // colour is mixed from was to t by f, so a new plate crossfades the shell
    property var saved: ({})
    property var previewing: null
    readonly property var t: previewing ?? saved
    property var was: ({})
    property real f: 1
    readonly property bool ready: t.accent !== undefined
    onTChanged: {
        was = snapshot();
        fade.restart();
    }
    NumberAnimation on f {
        id: fade
        running: false
        from: 0; to: 1
        duration: 600
        easing.type: Easing.InOutQuad
    }
    readonly property bool isSeed: !!saved.seed

    // ── the plate ───────────────────────────────────────────────────────────
    readonly property string plate: file(t.plate)
    readonly property string bloomMap: file(t.bloom)
    readonly property string softMap: file(t.soft)
    readonly property bool animated: !!t.animated
    readonly property string plateName: t.name ?? ""
    readonly property size plateSize: Qt.size(t.width || 1920, t.height || 1080)
    // the light source on the plate (0–1 from the top left), and the colour
    // the rays lean toward: the plate's brightest
    readonly property real lightX: num("lightX", 0.69)
    readonly property real lightY: num("lightY", 0.2)
    readonly property vector3d bright: {
        const a = arr(was.bright, [1, 0.9, 0.85]), b = arr(t.bright, a);
        return Qt.vector3d(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f);
    }
    readonly property var swatches: t.swatches ?? []

    // ── tokens ──────────────────────────────────────────────────────────────
    readonly property color accent: col("accent")      // the vivid primary
    readonly property color accent2: col("accent2")     // a second hue, clearly apart
    readonly property color onAccent: col("onAccent")    // text on an accent fill
    readonly property color onAccent2: col("onAccent2")
    readonly property color tint: col("tint")        // the glass: the plate's darkest, ~12%
    readonly property color glass: col("glass")
    readonly property color ink: col("ink")         // contact shadows, outlines
    readonly property color hair: col("hair")        // Hana's hair: the tint, a little up
    readonly property color fg: col("fg")
    readonly property color fgDim: col("fgDim")
    readonly property color surface: col("surface")
    readonly property color overlay: col("overlay")
    readonly property color urgent: col("urgent")
    readonly property color success: col("success")
    readonly property color warning: col("warning")

    // ── glass, all from the tokens ──────────────────────────────────────────
    // the tint at 40% over Hyprland's blur, a 1px light rim, a soft highlight
    // along the top edge, and the faint diagonal sheen leaning to the accent
    readonly property color glassFill:  Qt.alpha(tint, Style.glassOpacity)
    readonly property color glassDeep:  Qt.alpha(tint, 0.72)   // menus, the lock's field
    readonly property color rim:        Qt.alpha(fg, 0.16)
    readonly property color highlight:  Qt.alpha(fg, 0.22)
    readonly property color sheen:      Qt.alpha(fg, 0.13)
    readonly property color sheenTint:  Qt.alpha(accent, 0.12)
    readonly property color hover:      Qt.alpha(fg, 0.10)
    readonly property color well:       Qt.alpha(ink, 0.18)    // the bar's inset trays, cards
    readonly property color tile:       Qt.alpha(fg, 0.07)
    readonly property color track:      Qt.alpha(fg, 0.14)
    readonly property color shadowCol:  Qt.alpha(ink, 0.5)
    function at(c, a) { return Qt.alpha(c, a); }

    // the light every effect is graded with, shared by the plate and the
    // characters standing in it (Grade.qml computes it)
    readonly property Grade grade: Grade { bright: root.bright }

    // ── the mode ────────────────────────────────────────────────────────────
    // dark only; this answers `qs ipc call mode get` like every shell
    readonly property Mode mode: Mode { curve: Style.bloom; only: "dark" }
    readonly property bool dark: true
    readonly property real k: 1

    // ── preview (the wallpaper selector) ────────────────────────────────────
    function preview(tokens) { previewing = tokens; }
    function endPreview() { previewing = null; }

    // ── reading ─────────────────────────────────────────────────────────────
    function hex(v) { return typeof v === "string" && v.startsWith("#") ? v : null; }
    function col(name) {
        const b = hex(t[name]);
        if (!b) return "transparent";
        const a = hex(was[name]) ?? b;
        return f >= 1 || a === b ? b : Qt.tint(a, Qt.alpha(b, f));
    }
    function num(name, d) {
        const b = typeof t[name] === "number" ? t[name] : d;
        const a = typeof was[name] === "number" ? was[name] : b;
        return a + (b - a) * f;
    }
    function arr(v, d) { return Array.isArray(v) && v.length === 3 ? v : d; }
    // what's on screen now, in the file's terms, to fade from
    function snapshot() {
        const out = {};
        for (const k of ["accent", "accent2", "onAccent", "onAccent2", "tint", "glass", "ink", "hair", "fg",
                         "fgDim", "surface", "overlay", "urgent", "success", "warning"]) {
            const c = root[k];
            if (c.a > 0) out[k] = "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
        }
        out.lightX = lightX;
        out.lightY = lightY;
        out.bright = [bright.x, bright.y, bright.z];
        return out;
    }
    // seed paths are relative to the seed folder; state paths absolute
    function file(p) {
        if (!p) return "";
        const abs = p.startsWith("/") ? p : (saved.seed && t === saved ? seedDir + "/" + p : p);
        return abs.startsWith("/") ? "file://" + abs : abs;
    }
    function parse(text, isSeed) {
        try {
            const v = JSON.parse(text);
            if (v && v.accent) {
                if (isSeed) v.seed = true;
                saved = v;
                return true;
            }
        } catch (e) {}
        return false;
    }

    FileView {
        id: live
        path: root.stateDir + "/theme.json"
        blockLoading: true          // the first frame already has the plate's colours
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (!root.parse(text(), false)) seed.reload()
        onLoadFailed: seed.reload()
    }
    FileView {
        id: seed
        path: root.seedDir + "/theme.json"
        blockLoading: true
        printErrors: false
        onLoaded: if (!root.ready || root.isSeed) root.parse(text(), true)
    }
    Component.onCompleted: {
        if (!parse(live.text(), false))
            parse(seed.text(), true);
    }
}
