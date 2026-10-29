import QtQuick
import Quickshell.Io
import qs.deskwidget

// tests/test_desk_widget.py: a rice switch is one shell quitting and the next
// starting. Each reports what it found (the tab ui.json held, the cache), then
// moves the panel to Jobs, which DeskState writes to ui.json, and turns the
// rice dark: the panel restyles and stays as it was.
Item {
    property int step: 0
    readonly property var steps: [
        () => console.warn("POKE:" + JSON.stringify({ tag: "found", tab: DeskState.tab, loaded: DeskState.loaded,
                                                       open: DeskState.open, synced: DeskState.doc.synced_at })),
        () => DeskState.setTab("jobs"),
        () => DeskState.togglePanel("DP-1"),
        () => IpcRegistry.call("mode", "jump", "dark"),
        () => console.warn("POKE:" + JSON.stringify({ tag: "left", tab: DeskState.tab, panel: DeskState.panelOpen,
                                                       synced: DeskState.doc.synced_at })),
    ]
    Timer {
        interval: 600
        repeat: true
        running: true
        onTriggered: {
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step]();
            parent.step++;
        }
    }
}
