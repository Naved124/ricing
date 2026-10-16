pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// Small pill toasts under the bar: Caps Lock and microphone mute.
// Anything else asks through Shell.toast(icon, text) (e.g. screenshots, the launcher).
PanelWindow {
    id: win

    property string icon: "keyboard"
    property string text: ""
    property bool shown: false
    property bool armed: false

    function show(i, t) {
        if (!armed) return;
        icon = i;
        text = t;
        shown = true;
        hideTimer.restart();
    }

    screen: Hypr.focusedScreen
    anchors.top: true
    margins.top: 12 + 38 + 10
    implicitWidth: 320
    implicitHeight: 80
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nacre-toast"
    mask: Region {}

    Timer { interval: 1500; running: true; onTriggered: win.armed = true }
    Timer { id: hideTimer; interval: 1400; onTriggered: win.shown = false }

    Connections {
        target: Shell
        function onToast(icon, text) { win.show(icon, text); }
    }
    Connections {
        target: Audio
        function onMicMutedChanged() {
            win.show(Audio.micMuted ? "mic-off" : "mic", Audio.micMuted ? "Microphone muted" : "Microphone on");
        }
    }

    // Caps Lock has no event; its keyboard LED is cheap to watch.
    property bool caps: false
    onCapsChanged: show("keyboard", caps ? "Caps Lock on" : "Caps Lock off")

    Process {
        id: findLed
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null | head -n1"]
        stdout: StdioCollector { onStreamFinished: capsFile.path = text.trim() ? text.trim() + "/brightness" : "" }
    }
    FileView {
        id: capsFile
        blockLoading: true
        onLoaded: win.caps = text().trim() !== "0"
    }
    Timer {
        running: capsFile.path !== ""
        interval: 200
        repeat: true
        onTriggered: capsFile.reload()
    }

    Bloom {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        width: pillRow.implicitWidth + 32
        height: 36
        shown: win.shown
        origin: Qt.point(width / 2, 0)

        Glass {
            anchors.fill: parent
            radius: height / 2
            fill: Theme.glassStrong

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 8
                Icon { name: win.icon; size: 16; color: Theme.ink; anchors.verticalCenter: parent.verticalCenter }
                Label { text: win.text; size: Theme.uiSize + 1; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
