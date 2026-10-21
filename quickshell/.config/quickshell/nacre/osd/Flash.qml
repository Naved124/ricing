import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// The screenshot flash: the focused monitor goes white for 150 ms and
// fades back. At night nothing flashes white: an iridescent outline pulses
// round the screen's edge instead. rice-shot calls `qs -c nacre ipc call
// shell flash` after the capture, so the flash is never in the picture.
PanelWindow {
    id: win

    function flash() {
        anim.restart();
    }

    screen: Hypr.focusedScreen
    visible: anim.running
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nacre-flash"
    mask: Region {}

    property real pulse: 0

    Rectangle {
        anchors.fill: parent
        color: Theme.gleam
        opacity: win.pulse * 0.85 * (1 - Theme.k)
    }
    Iridescent {
        anchors.fill: parent
        radius: 0
        ring: 4
        sheen: 0.2
        opacity: win.pulse * Theme.k
        visible: Theme.k > 0
    }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: win; property: "pulse"; to: 1; duration: 30 }
        PauseAnimation { duration: 120 }
        NumberAnimation { target: win; property: "pulse"; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }
}
