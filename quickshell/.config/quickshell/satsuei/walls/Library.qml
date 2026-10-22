pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// The wallpaper folder (Settings.s.wallDir, ~/Pictures/Wallpapers, with its
// subfolders) as a list the selector draws: `satsuei-wall scan` prints one
// JSON line per picture (cached ones at once with their thumbnail and
// palette, new ones as "pending" first, then again when done; the cache is
// ~/.cache/satsuei/walls/<sha1>/), and one long-lived inotifywait watches the
// folder, so a picture dropped in shows up (a shimmer, then its card). It
// also turns the wallpaper over on its own (Settings.s.rotate: off, 15m, 30m,
// 1h, daily), picking from what the selector last showed (its folder chip
// and search).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: {
        const d = Settings.s.wallDir || "~/Pictures/Wallpapers";
        return (d.startsWith("~") ? home + d.slice(1) : d).replace(/\/+$/, "");
    }

    property var items: []                  // { path, rel, mtime, pending?, thumb, accent, … }
    property bool scanning: false
    property string error: ""
    // the folders under the top one: the selector's chips
    readonly property var folders: {
        const s = new Set();
        for (const w of items) if (w.rel && w.rel.includes("/")) s.add(w.rel.split("/")[0]);
        return [...s].sort();
    }

    // what the selector shows: a folder chip ("" for all), a search, a sort
    property string folder: ""
    property string query: ""
    readonly property var shown: {
        const q = query.toLowerCase();
        const list = items.filter(w => (!folder || w.rel.startsWith(folder + "/"))
                                       && (!q || w.rel.toLowerCase().includes(q)));
        const by = Settings.s.sort;
        if (by === "date") list.sort((a, b) => b.mtime - a.mtime);
        else if (by === "colour") list.sort((a, b) => hue(a.accent) - hue(b.accent));
        else list.sort((a, b) => a.rel.localeCompare(b.rel, undefined, { numeric: true }));
        return list;
    }
    // the hue of "#rrggbb", 0–360 (the colour sort, a rainbow strip); greys last
    function hue(h) {
        if (typeof h !== "string" || h.length < 7) return 999;
        const c = Qt.color(h);
        return c.hslSaturation < 0.08 ? 900 + c.hslLightness : c.hslHue * 360;
    }

    // the plate on screen now, by where it came from
    readonly property string current: Theme.saved.origin ?? ""
    function indexOf(path, list) { return (list ?? shown).findIndex(w => w.path === path); }

    // ── scanning ───────────────────────────────────────────────────────────
    property var seen: ({})
    function rescan() {
        if (scan.running) { again = true; return; }
        seen = {};
        error = "";
        scan.command = ["satsuei-wall", "scan", dir];
        scan.running = true;
    }
    property bool again: false
    // pictures arrive a line at a time; the list is renewed a few times a
    // second, not for every line (each renewal re-sorts and redraws the strip)
    property var incoming: ({})
    Timer { id: flush; interval: 300; onTriggered: root.merge() }
    function merge() {
        const news = Object.values(incoming);
        if (!news.length) return;
        incoming = {};
        const list = items.slice();
        for (const m of news) {
            const i = list.findIndex(w => w.path === m.path);
            if (i >= 0) list[i] = m; else list.push(m);
        }
        items = list;
    }
    Process {
        id: scan
        onRunningChanged: root.scanning = running
        stdout: SplitParser {
            onRead: line => {
                let m;
                try { m = JSON.parse(line); } catch (e) { return; }
                if (m.error && !m.path) { root.error = m.error; root.items = []; return; }
                if (m.done) {
                    root.merge();
                    root.items = root.items.filter(w => root.seen[w.path]);
                    return;
                }
                root.seen[m.path] = true;
                root.incoming[m.path] = m;
                if (!flush.running) flush.start();
            }
        }
        onExited: if (root.again) { root.again = false; root.rescan(); }
    }
    // the first scan once the shell has settled, and again for a new folder
    Timer { id: first; interval: 2500; running: true; onTriggered: root.rescan() }
    onDirChanged: {
        if (first.running) return;
        items = [];
        rescan();
        watch.running = false;
        watch.running = true;
    }

    // the watcher: any change in the folder, a rescan a moment later (the
    // scan is incremental, so this costs only the new pictures)
    Process {
        id: watch
        running: !first.running
        command: ["sh", "-c", 'mkdir -p "$1" && exec inotifywait -mrq -e close_write,moved_to,moved_from,delete,create --format x "$1"',
                  "sh", root.dir]
        stdout: SplitParser { onRead: settle.restart() }
        onExited: retry.restart()
    }
    Timer { id: settle; interval: 800; onTriggered: root.rescan() }
    // inotifywait missing or the folder gone: try again in a minute
    Timer { id: retry; interval: 60000; onTriggered: watch.running = true }

    // ── setting one ────────────────────────────────────────────────────────
    // the plate stays on its preview until theme.json says the new one is in
    property string applying: ""
    function apply(path) {
        if (!path) return;
        applying = path;
        giveUp.restart();
        Quickshell.execDetached(["satsuei-wall", "set", path]);
    }
    Connections {
        target: Theme
        function onSavedChanged() {
            if (!root.applying) return;
            root.applying = "";
            Theme.endPreview();
        }
    }
    Timer { id: giveUp; interval: 30000; onTriggered: if (root.applying) { root.applying = ""; Theme.endPreview(); } }

    // a picture's tokens over the ones on screen, for the selector's live
    // preview (no blur maps until it's applied)
    function previewTokens(w) {
        const t = Object.assign({}, Theme.saved);
        for (const k of ["accent", "accent2", "tint", "onAccent", "fg", "fgDim", "ink", "hair", "swatches",
                         "lightX", "lightY", "bright"])
            if (w[k] !== undefined) t[k] = w[k];
        return Object.assign(t, { plate: w.path, name: w.rel.split("/").pop(), origin: w.path, bloom: "", soft: "",
                                  width: w.width, height: w.height, animated: !!w.animated });
    }

    // ── next, previous, random (the IPC, the rotation) ─────────────────────
    function step(by) {
        const list = shown.filter(w => !w.pending && !w.error);
        if (!list.length) return "";
        const i = indexOf(current, list);
        const w = list[((i < 0 ? 0 : i + by) % list.length + list.length) % list.length];
        apply(w.path);
        return w.path;
    }
    function random() {
        const list = shown.filter(w => !w.pending && !w.error && w.path !== current);
        if (!list.length) return "";
        const w = list[Math.floor(Math.random() * list.length)];
        apply(w.path);
        return w.path;
    }

    // ── auto-rotate ────────────────────────────────────────────────────────
    readonly property var rotations: ({ "15m": 15, "30m": 30, "1h": 60 })
    function today() { return dayOf(new Date()); }
    function dayOf(d) {
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }
    function rotateDue() {
        const r = Settings.s.rotate, last = Settings.s.lastRotate;
        if (r === "daily") return !last || dayOf(new Date(Date.parse(last))) !== today();
        const mins = rotations[r];
        if (!mins) return false;
        const at = Date.parse(last);
        return isNaN(at) || Date.now() - at >= mins * 60000;
    }
    Timer {
        interval: 60000
        repeat: true
        running: Settings.s.rotate !== "off"
        onRunningChanged: if (running && !Settings.s.lastRotate) Settings.s.lastRotate = new Date().toISOString()
        onTriggered: {
            if (!root.rotateDue() || root.applying || Shell.wallsOpen) return;
            if (root.random()) Settings.s.lastRotate = new Date().toISOString();
        }
    }
}
