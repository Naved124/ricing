import QtQuick
import Quickshell
import qs.deskwidget

// tests/test_desk_widget.py: the fixture cache is in ~/.cache/desk. Tick a
// task on the card, open the full view, go through every database and page,
// edit a row (a select, a date, a multi-select), take an edit back as
// desk-sync would on a refusal, draft and add a row, move one to the trash,
// and report what each step shows.
Item {
    property int step: 0
    readonly property string at: Quickshell.env("DESK_POKE_AT") || ""
    function report(tag, extra) { console.warn("POKE:" + JSON.stringify(Object.assign({ tag: tag }, extra))); }
    function v(name, id, prop) { return DeskState.row(name, id)?.v[prop]; }
    property string task: ""
    property string ful: ""
    property string book: ""
    property string ghost: ""
    readonly property var steps: [
        () => report("loaded", { loaded: DeskState.loaded, open: DeskState.open, overdue: DeskState.overdue,
                                 stale: DeskState.stale, label: DeskState.syncedLabel, badge: DeskState.badge,
                                 order: DeskState.order, card: DeskState.cardShown,
                                 rows: DeskState.order.map(n => DeskState.sources[n]?.rows.length ?? -1) }),
        () => { task = DeskState.today[0].id; DeskState.toggle(task); },
        () => report("ticked", { done: DeskState.today[0].done, pending: DeskState.today[0].pending === true,
                                 open: DeskState.open, inView: v("today", task, "Done") }),
        () => DeskState.openView("DP-1", "today", task),
        () => report("view", { open: DeskState.viewOpen, source: DeskState.source, selected: DeskState.selected === task }),
        ...["countdowns", "jobs", "learning", "habits", "reading", "fulgurite", "prep", "ideas", "boxes", "brief", "weekly", "today"]
            .map(n => () => DeskState.pick(n)),
        () => {
            DeskState.set("today", task, "Area", "Cyber");
            DeskState.set("today", task, "Due", { start: "2026-11-02", end: null });
            ful = DeskState.sources.fulgurite.rows[0].id;
            DeskState.set("fulgurite", ful, "Area", ["Formats"]);
        },
        () => report("edited", { area: v("today", task, "Area"), due: v("today", task, "Due"), ful: v("fulgurite", ful, "Area"),
                                 pending: DeskState.pendingCount, foreign: DeskState.set("today", "nope", "Area", "RE") }),
        () => DeskState.dropEdit(`today|${task}|Area`, "refused: Shiny isn't one of Area's options"),
        () => report("rolled", { area: v("today", task, "Area"), error: DeskState.error, pending: DeskState.pendingCount }),
        () => { DeskState.pick("boxes"); DeskState.selected = "new"; },
        () => { ghost = DeskState.add("boxes", { Box: "Lame", Platform: "HTB" }); },
        () => report("added", { first: DeskState.sources.boxes.rows[0].v.Box, ghost: DeskState.sources.boxes.rows[0].ghost === true,
                                key: ghost !== "" }),
        () => { DeskState.pick("reading"); book = DeskState.sources.reading.rows[0].id; DeskState.trash("reading", book); },
        () => report("trashed", { gone: DeskState.row("reading", book) === null, finishedHidden: DeskState.hideFinished }),
        () => report("links", { js: DeskState.openLink("javascript:alert(1)"), http: DeskState.openLink("http://x.org"),
                                https: DeskState.openLink("https://x.org/a") }),
        () => { if (at) DeskState.openView("DP-1", at); else DeskState.viewOpen = false; },
    ]
    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step]();
            parent.step++;
        }
    }
}
