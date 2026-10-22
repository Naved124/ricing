pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.common

// Every character there is to cast, and who plays each role. The built-ins
// are QML (Rig + Part + Blob); the user's own are folders in
// ~/.config/satsuei/characters/<id>/: a `dance` clip (required), optional
// `idle`, `wave`, `sleep` and `thumb.png`, and an optional meta.json. A clip is
// a .gif or animated .webp, played as it is; a .png with "frames" in meta.json
// is a sprite sheet; an .apng (or a .png without "frames") is converted once
// with ffmpeg to an animated WebP under ~/.cache/satsuei/characters/<id>/, as
// Qt only shows an APNG's first frame. The folders are watched (each folder's
// own listing, and its meta.json), so a new character, clip or alignment shows
// up at once. A role whose character has gone falls back to Hana.
Singleton {
    id: root

    readonly property var builtins: [
        { id: "hana", name: "Hana", ja: "ハナ", builtin: true, file: "Hana.qml" },
        { id: "mochi", name: "Mochi", ja: "もち", builtin: true, file: "Mochi.qml" },
        { id: "kon", name: "Kon", ja: "コン", builtin: true, file: "Kon.qml" },
        { id: "bit", name: "Bit", ja: "ビット", builtin: true, file: "Bit.qml" },
        { id: "yuki", name: "Yuki", ja: "ゆき", builtin: true, file: "Yuki.qml" }
    ]
    property var customs: []
    readonly property var all: builtins.concat(customs)

    function byId(id) { return all.find(c => c.id === id) ?? builtins[0]; }
    readonly property var dancer: byId(Settings.s.dancer)
    readonly property var mascot: byId(Settings.s.mascotChar)

    // the roles: "dancer" (the media card) and "mascot" (the screen edge)
    function key(role) { return role === "mascot" ? "mascotChar" : "dancer"; }
    function set(role, id) {
        if (!all.some(c => c.id === id)) return false;
        Settings.s[key(role)] = id;
        return true;
    }
    function next(role) {
        const i = all.findIndex(c => c.id === Settings.s[key(role)]);
        const c = all[(i + 1) % all.length];
        Settings.s[key(role)] = c.id;
        return c.id;
    }

    // ── shuffle daily: a new character for each role every day ─────────────
    function today() {
        const d = new Date();
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }
    function shuffle() {
        if (!Settings.s.shuffleDaily || Settings.s.shuffledOn === today() || all.length < 2) return;
        for (const role of ["dancer", "mascot"]) {
            const others = all.filter(c => c.id !== Settings.s[key(role)]);
            Settings.s[key(role)] = others[Math.floor(Math.random() * others.length)].id;
        }
        Settings.s.shuffledOn = today();
    }
    Timer {
        // the first look once the folders are read; then every ten minutes
        // catches midnight
        interval: 600000
        repeat: true
        running: Settings.s.shuffleDaily
        onRunningChanged: if (running) Qt.callLater(root.shuffle)
        onTriggered: root.shuffle()
    }

    // ── the user's own ─────────────────────────────────────────────────────
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
                                  + "/satsuei/characters"
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
                                    + "/satsuei/characters"
    readonly property var states: ["dance", "idle", "wave", "sleep"]
    readonly property var metaDefaults: ({ nameJa: "", baseBpm: 100, scale: 1, offsetX: 0, offsetY: 0, flip: false,
                                           trimBottom: 0, puppet: 0.6, frames: 0, fps: 12 })

    // the folder has to be there to be watched
    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: { folders.folder = ""; folders.folder = "file://" + root.dir; }
    }
    FolderListModel {
        id: folders
        folder: "file://" + root.dir
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    Instantiator {
        id: found
        model: folders
        delegate: QtObject {
            id: one
            required property string fileName
            required property string filePath
            property var entry: null
            property string metaText: ""
            property var converted: ({})

            readonly property FolderListModel files: FolderListModel {
                folder: "file://" + one.filePath
                showDirs: false
                showHidden: false
                onCountChanged: one.later()
                onStatusChanged: one.later()
            }
            readonly property FileView meta: FileView {
                path: one.filePath + "/meta.json"
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: { one.metaText = text(); one.later(); }
                onLoadFailed: { one.metaText = ""; one.later(); }
            }
            // APNGs to WebP, each once (again when the source is newer)
            readonly property Process convert: Process {
                property var outs: []
                readonly property var base: ["sh", "-c", "while [ $# -gt 0 ]; do mkdir -p \"$(dirname \"$2\")\"; "
                          + "[ \"$2\" -nt \"$1\" ] || ffmpeg -loglevel error -y -i \"$1\" -c:v libwebp_anim -lossless 1 -loop 0 \"$2\" || exit 1; "
                          + "shift 2; done", "sh"]
                command: base
                onExited: code => {
                    if (code !== 0) return;       // ffmpeg missing or the file broken: left out
                    const c = Object.assign({}, one.converted);
                    for (const o of outs) c[o] = true;
                    one.converted = c;
                    one.later();
                }
            }
            readonly property Timer settle: Timer {
                interval: 120
                onTriggered: one.build()
            }
            function later() { settle.restart(); }

            function build() {
                const id = fileName;
                if (root.builtins.some(c => c.id === id)) { entry = null; root.refresh(); return; }
                let m = {};
                try { m = metaText ? JSON.parse(metaText) : {}; } catch (e) { m = {}; }
                const info = Object.assign({}, root.metaDefaults, { name: id }, m);
                const by = {};
                let thumb = "", stamp = "";
                for (let i = 0; i < files.count; i++) {
                    const name = files.get(i, "fileName"), path = files.get(i, "filePath");
                    const dot = name.lastIndexOf(".");
                    if (dot < 1) continue;
                    const base = name.slice(0, dot), ext = name.slice(dot + 1).toLowerCase();
                    if (name === "thumb.png") thumb = "file://" + path;
                    if (name === "meta.json") stamp = String(files.get(i, "fileModified"));
                    if (root.states.includes(base) && ["gif", "webp", "png", "apng"].includes(ext))
                        (by[base] = by[base] ?? {})[ext] = path;
                }
                const clips = {}, pending = [];
                for (const s of root.states) {
                    const f = by[s];
                    if (!f) continue;
                    if (f.gif || f.webp) clips[s] = { path: "file://" + (f.gif ?? f.webp), sheet: false };
                    else if (f.png && info.frames > 0) clips[s] = { path: "file://" + f.png, sheet: true };
                    else {
                        const src = f.apng ?? f.png, out = `${root.cache}/${id}/${s}.webp`;
                        if (converted[out]) clips[s] = { path: "file://" + out, sheet: false };
                        else pending.push(src, out);
                    }
                }
                if (pending.length && !convert.running) {
                    convert.outs = pending.filter((_, i) => i % 2);
                    convert.command = convert.base.concat(pending);
                    convert.running = true;
                }
                // a meta.json made or replaced after the start
                if (stamp !== metaStamp) { metaStamp = stamp; meta.reload(); }
                entry = clips.dance ? { id, name: info.name, ja: info.nameJa, builtin: false, file: "Custom.qml",
                                        dir: filePath, clips, thumb, meta: info } : null;
                root.refresh();
            }
            property string metaStamp: ""
            Component.onCompleted: later()
        }
        onObjectRemoved: root.refresh()
    }

    function refresh() { Qt.callLater(rebuild); }
    function rebuild() {
        const list = [];
        for (let i = 0; i < found.count; i++) {
            const e = found.objectAt(i)?.entry;
            if (e) list.push(e);
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        if (JSON.stringify(list) !== JSON.stringify(customs)) customs = list;
    }
}
