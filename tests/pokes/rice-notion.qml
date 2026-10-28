import QtQuick
import Quickshell.Io
import qs

// tests/test_notion.py: show the Notion card, feed it what `rice-notion watch`
// would print, tick things, open each tab of the panel, and report.
Item {
    property int step: 0
    readonly property string snap: JSON.stringify({
        kind: "snapshot", ok: true, error: "", at: 1761600000, today: "2026-10-28", inbox: true,
        tasks: { configured: true, statuses: ["Not started", "In progress", "Done"], items: [
            { id: "t1", title: "File taxes", icon: "🧾", url: "https://www.notion.so/t1", due: "2026-10-20", dueTime: false,
              overdue: true, today: false, status: "In progress", priority: "High" },
            { id: "t2", title: "Call mum", icon: "", url: "https://www.notion.so/t2", due: "2026-10-28T18:00:00.000+05:30",
              dueTime: true, overdue: false, today: true, status: "Not started", priority: null },
            { id: "t3", title: "Read Dune", icon: "", url: "https://www.notion.so/t3", due: "", dueTime: false,
              overdue: false, today: false, status: null, priority: null }] },
        agenda: { configured: true, items: [
            { id: "a1", title: "Standup", icon: "", url: "u", day: "2026-10-28", start: "2026-10-28T10:00:00.000+05:30",
              end: "2026-10-28T10:15:00.000+05:30", allDay: false },
            { id: "a2", title: "Trip", icon: "✈", url: "u", day: "2026-10-30", start: "2026-10-30", end: "", allDay: true }] },
        pinned: { configured: true, title: "Week", icon: "", url: "u", items: [
            { id: "b1", text: "Gym", done: true, group: "Health" }, { id: "b2", text: "Walk", done: false, group: "Health" },
            { id: "b3", text: "Ship it", done: false, group: "Work" }] },
        recent: [{ id: "r1", title: "Notes", icon: "", kind: "page", url: "u", edited: "2026-10-28T09:00:00.000Z" }]
    })
    readonly property var steps: [
        () => IpcRegistry.call("notion", "show"),
        () => Notion.take(snap),
        () => Notion.setDone("t2", true),
        () => Notion.setTodo("b2", true),
        () => console.warn("POKE:" + JSON.stringify({ tag: "read", shown: Notion.shown, tasks: Notion.tasks.length,
            open: Notion.filtered("open").map(t => t.id), today: Notion.filtered("today").map(t => t.id),
            overdue: Notion.filtered("overdue").map(t => t.id), someday: Notion.filtered("someday").map(t => t.id),
            ticked: [Notion.ticked(Notion.tasks[1]), Notion.ticked(Notion.pinned.items[1])],
            agenda: Notion.agenda.length, recent: Notion.recent.length, statuses: Notion.statuses,
            days: [Notion.dayName("2026-10-28"), Notion.dayName("2026-10-29")] })),
        () => IpcRegistry.call("notion", "open"),
        () => Notion.setTab("agenda"),
        () => Notion.setTab("pinned"),
        () => Notion.setTab("recent"),
        () => Notion.setTab("capture"),
        () => Notion.setTab("tasks"),
        () => Notion.setFilter("overdue"),
        () => Notion.take(JSON.stringify({ kind: "result", op: "done", ok: false, error: "offline (no route)" })),
        () => Notion.take(JSON.stringify({ kind: "snapshot", ok: false, stale: true, error: "offline (no route)" })),
        () => console.warn("POKE:" + JSON.stringify({ tag: "offline", ok: Notion.ok, error: Notion.error, tasks: Notion.tasks.length,
                                                       ticked: Notion.ticked(Notion.tasks[1]) })),
        () => IpcRegistry.call("notion", "close"),
        () => IpcRegistry.call("notion", "hide"),
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
