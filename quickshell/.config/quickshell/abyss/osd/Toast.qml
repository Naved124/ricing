pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// A quiet pill of glass under the bar: Caps Lock, the microphone muted, and
// whatever asks through Shell.toast(icon, text) (screenshots, the reef's
// pointer, "Abyss is always dark"). It rises in, then sinks away.
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
    margins.top: 10 + 34 + 10
    implicitWidth: 360
    implicitHeight: 80
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "abyss-toast"
    mask: Region {}

    Timer { interval: 1500; running: true; onTriggered: win.armed = true }
    Timer { id: hideTimer; interval: 1800; onTriggered: win.shown = false }

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

    // Caps Lock has no event; its keyboard LED is cheap to watch
    property bool caps: false
    onCapsChanged: show("keyboard", caps ? "Caps Lock on" : "Caps Lock off")
    Process {
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

    Glass {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8 + lift
        width: pillRow.implicitWidth + 30
        height: 34
        radius: height / 2
        fill: Theme.glassStrong
        opacity: win.shown ? 1 : 0
        property real lift: win.shown ? 0 : 14
        Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.durOpen : Theme.durClose; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.settle : Theme.sink } }
        Behavior on lift { NumberAnimation { duration: win.shown ? Theme.durOpen : Theme.durClose; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.settle : Theme.sink } }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8
            Icon { name: win.icon; size: 14; color: Theme.glow; anchors.verticalCenter: parent.verticalCenter }
            Label { text: win.text; size: 12.5; spacing: 0.06; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
