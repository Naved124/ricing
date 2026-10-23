pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Hot corners: a 2 px trigger in each corner of the screen that fires after
// the pointer rests there 250 ms; what each does is Settings → Desktop's
// (Mission Control, App Exposé, Desktop, Notification Center, Apps, Lock
// Screen, None). Off while a window is full screen.
Scope {
    id: root
    required property var screen

    function act(what) {
        switch (what) {
        case "missioncontrol": Shell.toggle("mission"); break;
        case "expose": Shell.toggle("expose"); break;
        case "desktop": Shell.gg(["desktop"]); break;
        case "notifications": Shell.toggle("notifications"); break;
        case "apps": Shell.toggle("apps"); break;
        case "lock": Shell.run(["rice", "lock"]); break;
        case "screensaver": Shell.run(["rice", "lock"]); break;
        }
    }

    Corner { at: "tl"; anchors { top: true; left: true } }
    Corner { at: "tr"; anchors { top: true; right: true } }
    Corner { at: "bl"; anchors { bottom: true; left: true } }
    Corner { at: "br"; anchors { bottom: true; right: true } }

    component Corner: PanelWindow {
        id: corner
        property string at
        readonly property string action: (Settings.desktop.hotCorners || {})[at] || "none"
        screen: root.screen
        implicitWidth: 2
        implicitHeight: 2
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "goldengate:hotcorner"
        color: "transparent"
        visible: action !== "none" && !Hypr.fullscreenOn(Hypr.monitorFor(root.screen))
        HoverHandler { id: h; onHoveredChanged: if (hovered) rest.restart(); else rest.stop() }
        Timer { id: rest; interval: 250; onTriggered: if (h.hovered) root.act(corner.action) }
    }
}
