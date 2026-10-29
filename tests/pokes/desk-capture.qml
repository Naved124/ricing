import QtQuick
import Quickshell.Io
import qs.deskwidget

// tests/test_desk_widget.py: Super+Shift+N's IPC twin opens the capture line
// on the focused screen; a blank line isn't sent, a real one closes it.
Item {
    property int step: 0
    readonly property var steps: [
        () => IpcRegistry.call("desk", "capture"),
        () => console.warn("POKE:" + JSON.stringify({ tag: "open", open: DeskState.captureOpen,
                                                       screen: DeskState.captureScreen, panel: DeskState.panelOpen })),
        () => console.warn("POKE:" + JSON.stringify({ tag: "blank", sent: DeskState.capture("   ") })),
        () => console.warn("POKE:" + JSON.stringify({ tag: "real", sent: DeskState.capture("idea: a rice for Notion") })),
        () => IpcRegistry.call("desk", "panel"),
        () => console.warn("POKE:" + JSON.stringify({ tag: "panel", panel: DeskState.panelOpen, capture: DeskState.captureOpen })),
        () => IpcRegistry.call("desk", "capture"),
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
