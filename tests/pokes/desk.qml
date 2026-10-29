import QtQuick
import Quickshell
import qs.deskwidget

// tests/test_desk_widget.py: the fixture cache is in ~/.cache/desk; open the
// panel, go through the four tabs, toggle a task, and report what it shows.
Item {
    property int step: 0
    readonly property string tab: Quickshell.env("DESK_POKE_TAB") || ""
    readonly property var steps: [
        () => DeskState.togglePanel("DP-1"),
        () => console.warn("POKE:" + JSON.stringify({ tag: "loaded", loaded: DeskState.loaded, open: DeskState.open,
                                                       overdue: DeskState.overdue, next: DeskState.nextLabel,
                                                       stale: DeskState.stale, label: DeskState.syncedLabel, badge: DeskState.badge,
                                                       today: DeskState.today.map(t => t.title) })),
        () => DeskState.setTab("brief"),
        () => DeskState.setTab("countdowns"),
        () => DeskState.setTab("jobs"),
        () => DeskState.setTab("today"),
        () => DeskState.toggle(DeskState.today[0].id),
        () => console.warn("POKE:" + JSON.stringify({ tag: "toggled", done: DeskState.today[0].done,
                                                       pending: DeskState.today[0].pending === true, open: DeskState.open })),
        () => DeskState.rollback(DeskState.today[0].id, "refused: not a task in the last synced Today list"),
        () => console.warn("POKE:" + JSON.stringify({ tag: "rolled", done: DeskState.today[0].done, error: DeskState.error })),
        () => console.warn("POKE:" + JSON.stringify({ tag: "links", js: DeskState.openLink("javascript:alert(1)"),
                                                       http: DeskState.openLink("http://x.org"), https: DeskState.openLink("https://x.org/a") })),
        () => { if (tab) DeskState.setTab(tab); },
    ]
    Timer {
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step]();
            parent.step++;
        }
    }
}
