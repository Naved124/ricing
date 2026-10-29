pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Desk: what desk-sync last mirrored from Notion (~/.cache/desk/state.json),
// read and watched, never fetched: the shell holds no credential and opens no
// connection. Writes go out as desk-sync subcommands with their arguments
// (set SOURCE PAGE PROP JSON, new SOURCE JSON, trash SOURCE PAGE, capture --
// TEXT, now), never through a shell string; desk-sync checks each against the
// synced schema again (allow.py).
//
// An edit shows at once, laid over the cache, and is taken back if desk-sync
// refuses it, the cache reports it failed, or two syncs go by without it.
// Where the card sits, its size, whether it shows, and the full view's database are in
// ~/.local/state/desk/ui.json, so every rice opens the Desk as the last left it.
//
// The same file in every shell (tests/test_desk_widget.py); a shell's look
// is its DeskTheme.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/desk/state.json"
    readonly property string uiPath: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/desk/ui.json"
    readonly property int staleMinutes: 15

    // the cache as desk-sync wrote it
    property var doc: ({})
    readonly property bool loaded: doc.version !== undefined
    readonly property var countdowns: doc.countdowns ?? []
    readonly property var brief: doc.brief ?? ({ title: "Daily brief", blocks: [] })
    readonly property var pages: Object.assign({ brief: brief }, doc.pages ?? {})
    readonly property var order: (doc.order ?? []).filter(n => n in sources || n in pages)
    readonly property var next: doc.summary?.next ?? null

    // what's on its way to Notion, laid over the cache
    property var edits: ({})            // "source|id|prop" -> { source, id, prop, value, at, syncs }
    property var trashed: ({})          // "source|id" -> { source, id, at, syncs }
    property var added: []              // [{ key, source, values, at, syncs }]
    readonly property var sources: build(doc.sources ?? {}, edits, trashed, added)

    // the card's Today: the synced list with its Done edits laid over it
    readonly property string doneField: doc.sources?.today?.done ?? "Done"
    readonly property var today: (doc.today ?? []).map(t => {
        const e = edits[`today|${t.id}|${doneField}`];
        return e === undefined ? t : Object.assign({}, t, { done: e.value === true, pending: true });
    })
    readonly property int open: today.filter(t => !t.done).length
    readonly property int overdue: today.filter(t => !t.done && t.state === "overdue").length

    // how fresh it is
    property double now: Date.now()
    readonly property double syncedAt: doc.synced_at ? Date.parse(doc.synced_at) : 0
    readonly property real ageMinutes: syncedAt ? Math.max(0, (now - syncedAt) / 60000) : Infinity
    readonly property bool stale: !syncedAt || ageMinutes > staleMinutes
    readonly property bool offline: (doc.stale ?? false) && (doc.error ?? "") !== ""
    readonly property string syncedLabel: !syncedAt ? "Not synced yet"
        : ageMinutes < 1 ? "Synced just now"
        : ageMinutes < 60 ? `Synced ${Math.floor(ageMinutes)}m ago`
        : ageMinutes < 48 * 60 ? `Synced ${Math.floor(ageMinutes / 60)}h ago`
        : `Synced ${Math.floor(ageMinutes / 1440)}d ago`
    readonly property string badge: !stale ? "" : offline ? (doc.error === "offline" ? "Offline" : "Stale") : "Stale"
    readonly property string reason: doc.error ?? ""
    readonly property int pendingCount: Object.keys(edits).length + Object.keys(trashed).length + added.length

    // a short line when something didn't go through
    property string error: ""
    property bool syncing: false

    // the card on the desktop: where it sits (0..1 of the free space) and its
    // size (a height of 0 follows what it holds, until it's first resized)
    property bool cardShown: true
    property size cardSize: Qt.size(360, 0)
    property bool cardResizing: false          // held: the outline and its dots are up
    property point cardAt: Qt.point(0.97, 0.62)       // clear of every rice's own desktop things

    // the full view, on one screen at a time (its name), and the capture line
    property bool viewOpen: false
    property string viewScreen: ""
    property string source: "today"          // a database or a page in `order`
    property string selected: ""             // a row id, or "new" for the draft
    property bool hideFinished: true
    property bool captureOpen: false
    property string captureScreen: ""

    function openView(screenName, what, id) {
        captureOpen = false;
        viewScreen = screenName ?? viewScreen;
        if (what !== undefined) pick(what);
        if (id !== undefined) selected = id;
        viewOpen = true;
        cache.reload();
    }
    function toggleView(screenName) {
        if (viewOpen && (screenName === undefined || screenName === viewScreen)) viewOpen = false;
        else openView(screenName);
    }
    function pick(what) {
        if (what === source) return;
        source = what;
        selected = "";
        saveUi();
    }
    function setHideFinished(on) { hideFinished = on; saveUi(); }
    function setCardShown(on) { cardShown = on; saveUi(); }
    function setCardSize(w, h) {
        cardSize = Qt.size(Math.max(0, Math.round(w)), Math.max(0, Math.round(h)));
        saveUi();
    }
    function setCardAt(x, y) {
        cardAt = Qt.point(Math.max(0, Math.min(1, x)), Math.max(0, Math.min(1, y)));
        saveUi();
    }
    function openCapture(screenName) {
        viewOpen = false;
        captureScreen = screenName ?? captureScreen;
        captureOpen = true;
    }
    function saveUi() {
        ui.setText(JSON.stringify({ cardShown: cardShown, cardX: cardAt.x, cardY: cardAt.y,
                                    cardW: cardSize.width, cardH: cardSize.height, source: source,
                                    hideFinished: hideFinished }) + "\n");
    }

    function say(msg) {
        error = String(msg).slice(0, 140);
        errorTimer.restart();
    }

    // ── reading the overlay ──────────────────────────────────────────────
    // equal values; dates by the moment they name (Notion writes 14:30 back as 14:30:00.000+05:30)
    function same(a, b) {
        const at = s => !s ? null : s.length === 10 ? s : Date.parse(s);
        if (a && b && typeof a === "object" && typeof b === "object" && "start" in a && "start" in b)
            return at(a.start) === at(b.start) && at(a.end) === at(b.end);
        return JSON.stringify(a ?? null) === JSON.stringify(b ?? null);
    }

    // finished: its done checkbox ticked, or a status in the "complete" group
    function closedOf(src, v) {
        if (src.done && v[src.done] === true) return true;
        for (const f of src.schema ?? []) {
            if (f.type !== "status") continue;
            const o = (f.options ?? []).find(o => o.name === v[f.name]);
            if (o && String(o.group).toLowerCase() === "complete") return true;
        }
        return false;
    }

    function build(srcs, e, tr, ad) {
        const out = {};
        const keys = Object.keys(e);
        for (const name of Object.keys(srcs)) {
            const s = srcs[name];
            const mine = keys.filter(k => e[k].source === name);
            const rows = (s.rows ?? []).filter(r => tr[`${name}|${r.id}`] === undefined).map(r => {
                const over = mine.filter(k => e[k].id === r.id);
                if (!over.length) return r;
                const v = Object.assign({}, r.v);
                for (const k of over) v[e[k].prop] = e[k].value;
                return Object.assign({}, r, { v: v, pending: true, closed: closedOf(s, v) });
            });
            const ghosts = ad.filter(a => a.source === name)
                             .map(a => ({ id: a.key, v: a.values, ghost: true, pending: true, closed: false }));
            out[name] = Object.assign({}, s, { rows: ghosts.concat(rows) });
        }
        return out;
    }

    function titleField(src) { return (src?.schema ?? []).find(f => f.type === "title")?.name ?? ""; }
    function field(src, name) { return (src?.schema ?? []).find(f => f.name === name) ?? null; }
    function row(name, id) { return (sources[name]?.rows ?? []).find(r => r.id === id) ?? null; }

    // a value as a line of text, for lists and read-only fields
    function show(f, v) {
        if (v === null || v === undefined || v === "") return "";
        if (f?.type === "checkbox") return v ? "yes" : "";
        if (f?.type === "date") return dateLabel(v.start) + (v.end ? " → " + dateLabel(v.end) : "");
        if (typeof v === "object" && typeof v.length === "number") return Array.prototype.join.call(v, ", ");
        if (typeof v === "string" && /^\d{4}-\d\d-\d\dT/.test(v)) return dateLabel(v);
        return String(v);
    }
    function dateLabel(iso) {
        if (!iso) return "";
        const d = new Date(iso.length === 10 ? iso + "T00:00:00" : iso);
        if (isNaN(d)) return iso;
        const sameYear = d.getFullYear() === new Date(now).getFullYear();
        const day = Qt.formatDate(d, sameYear ? "ddd d MMM" : "d MMM yyyy");
        return iso.length === 10 ? day : day + " " + Qt.formatTime(d, "HH:mm");
    }

    // what desk-sync will make of text, so the overlay matches the next sync
    function cleanText(s, lines) {
        const t = String(s ?? "").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f​-‏‪-‮⁠-⁤﻿]/g, "");
        if (!lines) return t.split(/\s+/).filter(x => x).join(" ");
        return t.split("\n").map(l => l.split(/[ \t\r]+/).filter(x => x).join(" ")).join("\n").trim();
    }

    // ── writes ───────────────────────────────────────────────────────────
    function set(name, id, prop, value) {
        const r = (doc.sources?.[name]?.rows ?? []).find(r => r.id === id);
        if (!r) return false;
        const k = `${name}|${id}|${prop}`;
        const e = Object.assign({}, edits);
        if (same(r.v[prop], value)) delete e[k];
        else e[k] = { source: name, id: id, prop: prop, value: value, at: Date.now(), syncs: 0 };
        edits = e;
        run(["desk-sync", "set", name, id, prop, JSON.stringify(value)], (code, err) => {
            if (code !== 0) root.dropEdit(k, err || "desk-sync refused it");
        });
        return true;
    }
    // a new row: its key while it's on its way ("" if there's no such database)
    function add(name, values) {
        if (!(name in (doc.sources ?? {}))) return "";
        const key = "new-" + Date.now() + "-" + Math.floor(Math.random() * 1e6);
        added = added.concat([{ key: key, source: name, values: values, at: Date.now(), syncs: 0 }]);
        run(["desk-sync", "new", name, JSON.stringify(values)], (code, err) => {
            if (code !== 0) root.dropAdded(key, err || "desk-sync refused it");
        });
        return key;
    }
    function trash(name, id) {
        if (!row(name, id) || row(name, id).ghost) return false;
        const k = `${name}|${id}`;
        const t = Object.assign({}, trashed);
        t[k] = { source: name, id: id, at: Date.now(), syncs: 0 };
        trashed = t;
        if (selected === id) selected = "";
        run(["desk-sync", "trash", name, id], (code, err) => {
            if (code !== 0) root.dropTrash(k, err || "desk-sync refused it");
        });
        return true;
    }
    // the card's checkbox: Done on a Today task
    function toggle(id) {
        const t = today.find(t => t.id === id);
        return t ? set("today", id, doneField, !t.done) : false;
    }
    function capture(text) {
        const t = String(text ?? "").trim();
        if (!t) return false;
        run(["desk-sync", "capture", "--", t], (code, err) => {
            if (code !== 0) root.say(err || "capture failed");
        });
        return true;
    }
    function syncNow() {
        syncing = true;
        syncingTimer.restart();
        run(["desk-sync", "now"], (code, err) => { if (code !== 0) root.say(err || "couldn't start a sync"); });
    }
    // only on a click, only https, and the URL as one argument
    function openLink(url) {
        if (typeof url !== "string" || !/^https:\/\/[^\s"'<>]+$/.test(url)) return false;
        Quickshell.execDetached(["xdg-open", url]);
        return true;
    }

    function dropEdit(k, why) {
        if (edits[k] === undefined) return;
        const e = Object.assign({}, edits);
        delete e[k];
        edits = e;
        if (why) say(why);
    }
    function dropTrash(k, why) {
        if (trashed[k] === undefined) return;
        const t = Object.assign({}, trashed);
        delete t[k];
        trashed = t;
        if (why) say(why);
    }
    function dropAdded(key, why) {
        if (!added.some(a => a.key === key)) return;
        added = added.filter(a => a.key !== key);
        if (selected === key) selected = "";
        if (why) say(why);
    }

    // the last line desk-sync printed on stderr, without its "desk-sync: "
    function lastLine(s) {
        const lines = String(s ?? "").trim().split("\n");
        return lines[lines.length - 1].replace(/^desk-sync:\s*/, "");
    }

    function run(command, done) {
        job.createObject(root, { command: command, done: done });
    }
    Component {
        id: job
        Process {
            id: proc
            property var done: null
            property int code: -1
            property bool exitedYet: false
            property bool readYet: false
            function finish() {
                if (!exitedYet || !readYet) return;
                if (done) done(code, root.lastLine(err.text));
                proc.destroy();
            }
            running: true
            stderr: StdioCollector {
                id: err
                onStreamFinished: { proc.readYet = true; proc.finish(); }
            }
            onExited: (exitCode, exitStatus) => { proc.code = exitCode; proc.exitedYet = true; proc.finish(); }
        }
    }

    // ── reading the cache ────────────────────────────────────────────────
    function take(text) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return;                       // half a file can't happen (desk-sync renames); a bad one is ignored
        }
        if (!d || typeof d !== "object") return;
        const fresh = d.synced_at !== doc.synced_at;
        doc = d;
        syncing = false;
        settle(fresh && !d.stale);
    }

    // match what's on its way against what came back
    function settle(fresh) {
        const errs = doc.errors ?? [];
        const failed = (since, test) => errs.find(x => test(x) && Date.parse(x.at) >= since - 2000);
        let why = "";

        const e = Object.assign({}, edits);
        for (const k of Object.keys(e)) {
            const p = e[k];
            const r = (doc.sources?.[p.source]?.rows ?? []).find(r => r.id === p.id);
            const f = failed(p.at, x => x.page === p.id && (x.prop === p.prop || x.op === "toggle"));
            if (!r) { delete e[k]; continue; }
            if (f) { delete e[k]; why = f.message; continue; }
            if (root.same(r.v[p.prop], p.value)) { delete e[k]; continue; }
            if (fresh && ++p.syncs >= 2) { delete e[k]; why = "a change didn't reach Notion"; }
        }
        edits = e;

        const t = Object.assign({}, trashed);
        for (const k of Object.keys(t)) {
            const p = t[k];
            const there = (doc.sources?.[p.source]?.rows ?? []).some(r => r.id === p.id);
            const f = failed(p.at, x => x.op === "trash" && x.page === p.id);
            if (!there) { delete t[k]; continue; }
            if (f) { delete t[k]; why = f.message; continue; }
            if (fresh && ++p.syncs >= 2) { delete t[k]; why = "a row didn't reach the trash"; }
        }
        trashed = t;

        const kept = [];
        for (const a of added) {
            const src = doc.sources?.[a.source];
            const title = titleField(src);
            const f = failed(a.at, x => x.op === "new" && x.source === a.source);
            const arrived = (src?.rows ?? []).some(r => r.v[title] === a.values[title]
                                                   && Date.parse(r.created) >= a.at - 120000);
            if (f) { why = f.message; continue; }
            if (arrived) {
                if (selected === a.key) selected = (src.rows.find(r => r.v[title] === a.values[title]) ?? {}).id ?? "";
                continue;
            }
            if (fresh && ++a.syncs >= 2) { why = "a new row didn't reach Notion"; continue; }
            kept.push(a);
        }
        if (kept.length !== added.length) added = kept;
        if (why) say(why);
    }

    FileView {
        id: cache
        path: root.cachePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.take(text())
    }
    FileView {
        id: ui
        path: root.uiPath
        printErrors: false
        onLoaded: {
            try {
                const u = JSON.parse(text());
                if (typeof u.cardShown === "boolean") root.cardShown = u.cardShown;
                if (typeof u.cardX === "number" && typeof u.cardY === "number")
                    root.cardAt = Qt.point(Math.max(0, Math.min(1, u.cardX)), Math.max(0, Math.min(1, u.cardY)));
                if (typeof u.cardW === "number" && typeof u.cardH === "number" && u.cardW > 0)
                    root.cardSize = Qt.size(u.cardW, Math.max(0, u.cardH));
                if (typeof u.source === "string") root.source = u.source;
                if (typeof u.hideFinished === "boolean") root.hideFinished = u.hideFinished;
            } catch (e) {}
        }
    }

    // the age label, and a reread in case a rename slipped past the watch
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: { root.now = Date.now(); cache.reload(); }
    }
    Timer { id: errorTimer; interval: 7000; onTriggered: root.error = "" }
    Timer { id: syncingTimer; interval: 30000; onTriggered: root.syncing = false }
}
