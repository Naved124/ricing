pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.services

// Volume, brightness and the microphone: a small strip of paper at the
// bottom centre, turned −1°. The level is pencil hatching in ink with a red
// dot where it ends, and the percentage in Kalam. The speaker goes to 150%:
// the strip's full length is 150%, with a tick at 100. It shows when a
// level changes and is tossed away 1.2 s later.
PanelWindow {
    id: win

    property string kind: "volume"     // "volume" | "brightness" | "mic"
    property bool shown: false
    property bool armed: false         // ignore the initial values at startup

    readonly property real value: kind === "volume" ? (Audio.muted ? 0 : Audio.volume)
        : kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : Brightness.level
    readonly property real max: kind === "volume" ? Audio.maxVolume : 1
    readonly property string glyph: kind === "brightness" ? "sun"
        : kind === "mic" ? "mic" : (Audio.muted ? "speaker-off" : "speaker")

    function show(k) {
        if (!armed) return;
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    screen: Hypr.focusedScreen
    anchors.bottom: true
    margins.bottom: 40
    implicitWidth: 360
    implicitHeight: 120
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "paper-osd"
    mask: Region {}
    visible: shown || strip.opacity > 0

    Timer { interval: 1500; running: true; onTriggered: win.armed = true }
    Timer { id: hideTimer; interval: 1200; onTriggered: win.shown = false }

    // qs -c paper ipc call osd trigger volume|brightness|mic
    IpcHandler {
        target: "osd"
        function trigger(kind: string): void { win.show(kind); }
    }

    Connections {
        target: Audio
        function onVolumeChanged() { win.show("volume"); }
        function onMutedChanged() { win.show("volume"); }
        function onMicVolumeChanged() { win.show("mic"); }
        function onMicMutedChanged() { win.show("mic"); }
    }
    Connections {
        target: Brightness
        function onLevelChanged() { win.show("brightness"); }
    }

    Sheet {
        id: strip
        x: (win.width - width) / 2
        width: 300
        height: 54
        seed: 300
        tilt: -1
        tiltContent: true

        // dropped in, tossed away
        property real drop: win.shown ? 0 : 50
        y: win.height - height - 24 + drop
        opacity: win.shown ? 1 : 0
        Behavior on drop { NumberAnimation { duration: win.shown ? 260 : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.drop : Theme.toss } }
        Behavior on opacity { NumberAnimation { duration: win.shown ? 120 : Theme.durPanelOut; easing.type: Easing.InQuad } }

        Glyph {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            name: win.glyph
            size: 22
            color: Theme.ink
        }

        // the track: a pencil line, the hatched level over it
        Item {
            id: track
            x: 52
            anchors.verticalCenter: parent.verticalCenter
            width: 180
            height: 14

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Qt.alpha(Theme.pencil, 0.45)
                border.width: 1
            }
            // 100% on a 150% scale
            Rectangle {
                visible: win.max > 1
                x: track.width / win.max - 0.5
                y: -3
                width: 1
                height: track.height + 6
                color: Qt.alpha(Theme.pencil, 0.6)
            }
            Item {
                id: fill
                width: track.width * Math.min(1, win.value / win.max)
                height: track.height
                clip: true          // the hatching never leaves the track, whatever the level
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Hatch {
                    width: track.width
                    height: track.height
                }
            }
            // where it ends: a red dot
            Rectangle {
                x: fill.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: Theme.red
            }
        }

        Hand {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(win.value * 100)}%`
            size: 20
            color: win.value > 1 ? Theme.red : Theme.ink
            font.features: { "tnum": 1 }
        }
    }
}
