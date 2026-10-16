pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Things lying on the desk, under the windows (the bottom layer): the
// tear-off calendar near the top right and the wastebasket in the bottom
// right corner. On the first monitor only; out of the way whenever a
// window there is fullscreen. Only the two take clicks.
PanelWindow {
    id: win

    screen: Quickshell.screens[0] ?? null
    readonly property var monitor: Hypr.monitorFor(screen)

    visible: !Hypr.fullscreenOn(monitor)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "paper-desk"

    mask: Region {
        Region { item: calendar }
        Region { item: bin }
    }

    TearOff {
        id: calendar
        x: win.width - width - Math.max(34, Theme.gapsOut + 12)
        y: 10 + 44 + 48
    }

    Wastebasket {
        id: bin
        x: win.width - width - 30
        y: win.height - height - 14
    }
}
