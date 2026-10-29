import QtQuick
import Quickshell.Io
import qs.deskwidget

// tests/test_desk_widget.py: a rice switch is one shell quitting and the next
// starting. Each reports what it found (what ui.json held, the cache), then
// opens the view on the Reading list, which DeskState writes to ui.json, and
// turns the rice dark: the view restyles and stays as it was.
Item {
    property int step: 0
    readonly property var steps: [
        () => console.warn("POKE:" + JSON.stringify({ tag: "found", source: DeskState.source, loaded: DeskState.loaded,
                                                       open: DeskState.open, synced: DeskState.doc.synced_at,
                                                       card: DeskState.cardShown, x: DeskState.cardAt.x,
                                                       w: DeskState.cardSize.width, h: DeskState.cardSize.height })),
        () => { DeskState.cardResizing = true; DeskState.setCardSize(520, 300); DeskState.cardResizing = false; },
        () => DeskState.openView("DP-1", "reading"),
        () => IpcRegistry.call("mode", "jump", "dark"),
        () => console.warn("POKE:" + JSON.stringify({ tag: "left", source: DeskState.source, view: DeskState.viewOpen,
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
