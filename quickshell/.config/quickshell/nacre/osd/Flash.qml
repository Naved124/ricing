import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The screenshot flash: the focused monitor goes white for 150 ms and
// fades back. rice-shot calls `qs -c nacre ipc call shell flash` after
// the capture, so the flash is never in the picture.
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

    Rectangle {
        id: sheet
        anchors.fill: parent
        color: "white"
        opacity: 0
    }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: sheet; property: "opacity"; to: 0.85; duration: 30 }
        PauseAnimation { duration: 120 }
        NumberAnimation { target: sheet; property: "opacity"; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }
}
