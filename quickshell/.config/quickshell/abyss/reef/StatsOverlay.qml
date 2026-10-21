pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The reef's numbers over its corner, like the mock's stats line: frame rate
// and cost, what it draws at what size, how many of each creature, and why
// it runs as it does. Super+Ctrl+Shift+R (Shell.reefStats); click-through.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData
    readonly property var reef: Reefs.on(screen, Reefs.count)
    property var s: ({})

    visible: Shell.reefStats && !!reef
    anchors { bottom: true; right: true }
    margins { bottom: 14; right: 14 }
    implicitWidth: card.width
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "abyss-stats"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Timer {
        interval: 500
        repeat: true
        running: win.visible
        triggeredOnStart: true
        onTriggered: win.s = win.reef ? win.reef.stats() : ({})
    }

    Rectangle {
        id: card
        width: text.implicitWidth + 28
        height: text.implicitHeight + 24
        radius: Theme.radiusPanel
        color: Theme.glassStrong
        border.color: Theme.line
        Text {
            id: text
            x: 14
            y: 12
            color: Theme.inkDim
            font.family: Theme.fontMono
            font.pixelSize: 11
            lineHeight: 1.5
            text: !win.s.scene ? "—" : [
                `${win.s.fps} fps · ${win.s.ms} ms/frame (world ${win.s.msWorld} · canvas ${win.s.msDraw})`,
                `scene ${win.s.scene} · bloom ${win.s.bloom} · out ${win.s.out}`,
                `ripple grid ${win.s.grid} · ${win.s.plankton} plankton · ${win.s.fish} fish · ${win.s.jellies} jellies`,
                `${win.s.throttle}${win.s.interactive ? "" : " · pointer off"}${win.s.reducedMotion ? " · reduced motion" : ""}`
            ].join("\n")
        }
    }
}
