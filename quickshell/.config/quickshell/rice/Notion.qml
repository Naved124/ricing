pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Notion for the Notion widget (NotionCard.qml on the desk, NotionPanel.qml
// over everything), through `rice-notion watch`: one process, started only
// while the card is shown or the panel is open, that prints a snapshot (tasks,
// agenda, the pinned page's to-dos, recent pages) every `refresh` seconds and
// takes commands on its standard input. Settings and the token are in
// ~/.config/rice/notion.toml, never here; the card's place and whether it's
// shown are in ~/.local/state/rice/notion.json, which the rices' control
// centres read for their Notion tile.
//
// A tick is shown at once (`pending`) and the next snapshot confirms it, or
// takes it back with the error.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice"
    readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/rice/notion.toml"

    // ── what the user chose (notion.json) ───────────────────────────────────
    property bool shown: false
    property var at: ({ x: 0.03, y: 0.62 })    // the card's place, as fractions of the free space
    property string tab: "tasks"               // the panel's tab
    property string filter: "open"             // tasks: open | today | overdue | someday
    property bool panelOpen: false

    function save() {
        stateFile.setText(JSON.stringify({ shown: root.shown, at: root.at, tab: root.tab, filter: root.filter }) + "\n");
    }
    function setShown(on) { shown = on; save(); }
    function setAt(x, y) { at = ({ x: x, y: y }); save(); }
    function setTab(t) { tab = t; save(); }
    function setFilter(f) { filter = f; save(); }

    FileView {
        id: stateFile
        path: root.stateDir + "/notion.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.shown = !!d.shown;
                if (d.at && d.at.x !== undefined) root.at = d.at;
                if (d.tab) root.tab = d.tab;
                if (d.filter) root.filter = d.filter;
            } catch (e) {}
        }
    }

    // ── what Notion said ────────────────────────────────────────────────────
    property var tasks: []          // [{ id, title, icon, url, due, dueTime, overdue, today, status, priority }]
    property var statuses: []       // the status property's options
    property var agenda: []         // [{ id, title, icon, url, day, start, end, allDay }]
    property var pinned: ({ configured: false, title: "", url: "", items: [] })   // items: [{ id, text, done, group }]
    property var recent: []         // [{ id, title, icon, kind, url, edited }]
    property bool configured: false // a tasks database is set
    property bool canCapture: false
    property bool setup: false      // no token yet
    property bool ok: true
    property bool stale: true
    property string error: ""
    property int syncedAt: 0             // when the snapshot was taken (s)
    property string today: ""
    property bool busy: false       // a command is under way
    property var pending: ({})      // id → the tick being sent

    readonly property bool wanted: shown || panelOpen

    function ticked(item) { return pending[item.id] !== undefined ? pending[item.id] : !!item.done; }

    function send(cmd) {
        if (!watcher.running) return;
        busy = true;
        watcher.write(JSON.stringify(cmd) + "\n");
    }
    function setDone(id, on) { pending = Object.assign({}, pending, { [id]: on }); send({ op: "done", id: id, on: on }); }
    function setTodo(id, on) { pending = Object.assign({}, pending, { [id]: on }); send({ op: "todo", id: id, on: on }); }
    function setStatus(id, v) { send({ op: "status", id: id, value: v }); }
    function add(text, due) { if (text.trim()) send({ op: "add", text: text.trim(), due: due || "" }); }
    function capture(text) { if (text.trim()) send({ op: "capture", text: text.trim() }); }
    function refresh() { send({ op: "refresh" }); }
    function open(url) { if (url) Quickshell.execDetached(["xdg-open", url]); }

    // the tasks the filter lets through
    function filtered(f) {
        const list = tasks;        // a ticked one stays, struck through, until the next read
        if (f === "today") return list.filter(t => t.today || t.overdue);
        if (f === "overdue") return list.filter(t => t.overdue);
        if (f === "someday") return list.filter(t => !t.due);
        return list;
    }

    function take(line) {
        let d;
        try { d = JSON.parse(line); } catch (e) { return; }
        if (d.kind === "result") {
            if (!d.ok) error = d.error;
            return;
        }
        if (d.kind !== "snapshot") return;
        busy = false;
        ok = d.ok !== false;
        stale = !!d.stale;
        setup = !!d.setup;
        error = d.error ?? "";
        if (d.at) syncedAt = d.at;
        if (d.today) today = d.today;
        if (d.tasks) {
            configured = !!d.tasks.configured;
            tasks = d.tasks.items ?? [];
            statuses = d.tasks.statuses ?? [];
        }
        if (d.agenda) agenda = d.agenda.items ?? [];
        if (d.pinned) pinned = d.pinned;
        if (d.recent) recent = d.recent;
        canCapture = !!d.inbox;
        // a fresh read settles every tick: a ticked task has left the open list,
        // a pinned to-do says what it is now
        if (!d.stale) pending = ({});
    }

    // "just now", "4 min ago", "2 h ago"
    function ago(now) {
        if (!syncedAt) return "never";
        const s = Math.max(0, Math.floor(now / 1000) - syncedAt);
        return s < 60 ? "just now" : s < 3600 ? `${Math.floor(s / 60)} min ago` : `${Math.floor(s / 3600)} h ago`;
    }
    // "Today", "Tomorrow", "Mon 3", or the date
    function dayName(iso) {
        if (!iso) return "";
        const d = new Date(iso.slice(0, 10) + "T00:00:00");
        const t = new Date((today || new Date().toISOString().slice(0, 10)) + "T00:00:00");
        const n = Math.round((d - t) / 86400000);
        if (n === 0) return "Today";
        if (n === 1) return "Tomorrow";
        if (n === -1) return "Yesterday";
        if (n > 1 && n < 7) return d.toLocaleDateString(Qt.locale(), "ddd");
        return d.toLocaleDateString(Qt.locale(), "d MMM");
    }
    function timeOf(iso) {
        return iso && iso.indexOf("T") > 0 ? new Date(iso).toLocaleTimeString(Qt.locale(), "HH:mm") : "";
    }

    Process {
        id: watcher
        running: root.wanted
        command: ["rice-notion", "watch"]
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.take(data) }
        onExited: code => { root.busy = false; if (code !== 0) root.error = `rice-notion stopped (${code})`; }
    }

    // a change to notion.toml starts the reader again with it
    FileView {
        path: root.configFile
        watchChanges: true
        printErrors: false
        onFileChanged: if (watcher.running) { watcher.running = false; restart.start(); }
    }
    Timer { id: restart; interval: 300; onTriggered: watcher.running = Qt.binding(() => root.wanted) }
}
