pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Desk: what desk-sync last mirrored from Notion (~/.cache/desk/state.json),
// read and watched, never fetched: the shell holds no credential and opens no
// connection. Writes go out as desk-sync subcommands with their arguments
// (toggle PAGE_ID, capture -- TEXT, now), never through a shell string.
// A toggle shows at once and is rolled back if desk-sync refuses it, the
// cache reports it failed, or two syncs go by without it.
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
    readonly property var jobs: doc.jobs ?? []
    readonly property var brief: doc.brief ?? ({ title: "Daily brief", blocks: [] })
    readonly property var next: doc.summary?.next ?? null

    // Today with the toggles still on their way applied over it
    property var pending: ({})          // page id -> { done, at, syncs }
    readonly property var today: (doc.today ?? []).map(t => pending[t.id] === undefined ? t
                                                      : Object.assign({}, t, { done: pending[t.id].done, pending: true }))
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

    // the pill's line: "3 · 4d · Placement"
    readonly property string nextLabel: next ? `${next.days === 0 ? "today" : next.days + "d"} · ${next.event}` : ""

    // a short line under the panel when something didn't go through
    property string error: ""
    property bool syncing: false

    // the panel and the capture line, on one screen at a time (its name)
    property bool panelOpen: false
    property string panelScreen: ""
    property string tab: "today"
    readonly property var tabs: ["today", "brief", "countdowns", "jobs"]
    property bool captureOpen: false
    property string captureScreen: ""

    function togglePanel(screenName) {
        if (panelOpen && (screenName === undefined || screenName === panelScreen)) {
            panelOpen = false;
            return;
        }
        captureOpen = false;
        panelScreen = screenName ?? panelScreen;
        panelOpen = true;
        cache.reload();
    }
    function setTab(t) {
        if (tabs.indexOf(t) < 0 || t === tab) return;
        tab = t;
        ui.setText(JSON.stringify({ tab: t }) + "\n");
    }
    function openCapture(screenName) {
        panelOpen = false;
        captureScreen = screenName ?? captureScreen;
        captureOpen = true;
    }

    function say(msg) {
        error = String(msg).slice(0, 120);
        errorTimer.restart();
    }

    // ── writes ───────────────────────────────────────────────────────────
    function toggle(id) {
        const task = today.find(t => t.id === id);
        if (!task) return;
        const p = Object.assign({}, pending);
        const synced = (doc.today ?? []).find(t => t.id === id);
        if (p[id] !== undefined) delete p[id];        // a second toggle cancels the first
        else p[id] = { done: !synced.done, at: Date.now(), syncs: 0 };
        pending = p;
        run(["desk-sync", "toggle", id], (code, err) => {
            if (code === 0) return;
            root.rollback(id, err || "desk-sync refused it");
        });
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

    function rollback(id, why) {
        if (pending[id] === undefined) return;
        const p = Object.assign({}, pending);
        delete p[id];
        pending = p;
        say(why);
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
        settle(fresh);
    }

    // match what's pending against what came back
    function settle(fresh) {
        const keys = Object.keys(pending);
        if (!keys.length) return;
        const p = Object.assign({}, pending);
        let why = "";
        for (const id of keys) {
            const synced = (doc.today ?? []).find(t => t.id === id);
            const failed = (doc.errors ?? []).find(e => e.page === id && Date.parse(e.at) >= p[id].at - 2000);
            if (!synced) { delete p[id]; continue; }
            if (failed) { delete p[id]; why = failed.message; continue; }
            if (synced.done === p[id].done) { delete p[id]; continue; }
            if (fresh && !doc.stale && ++p[id].syncs >= 2) { delete p[id]; why = "the change didn't reach Notion"; }
        }
        pending = p;
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
                const t = JSON.parse(text()).tab;
                if (root.tabs.indexOf(t) >= 0) root.tab = t;
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
    Timer { id: errorTimer; interval: 6000; onTriggered: root.error = "" }
    Timer { id: syncingTimer; interval: 20000; onTriggered: root.syncing = false }
}
