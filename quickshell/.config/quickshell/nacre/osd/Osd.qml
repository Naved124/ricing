pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// Volume and brightness: a vertical pearl capsule at the right edge,
// centred, with an iridescent fill and the value in Italiana.
// Appears when either changes and hides after 1.2 s.
PanelWindow {
    id: win

    property string kind: "volume"     // "volume" | "brightness"
    property bool shown: false
    property bool armed: false         // ignore the initial values at startup

    readonly property real value: kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.level
    readonly property real max: kind === "volume" ? Audio.maxVolume : 1
    readonly property string icon: kind === "volume" ? Audio.icon : "brightness"

    function show(k) {
        if (!armed) return;
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    screen: Hypr.focusedScreen
    anchors.right: true
    margins.right: 18
    implicitWidth: 56 + 40
    implicitHeight: 230 + 40
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nacre-osd"
    mask: Region {}

    Timer { interval: 1500; running: true; onTriggered: win.armed = true }

    // qs -c nacre ipc call osd trigger volume|brightness
    IpcHandler {
        target: "osd"
        function trigger(kind: string): void { win.show(kind); }
    }
    Timer { id: hideTimer; interval: 1200; onTriggered: win.shown = false }

    Connections {
        target: Audio
        function onVolumeChanged() { win.show("volume"); }
        function onMutedChanged() { win.show("volume"); }
    }
    Connections {
        target: Brightness
        function onLevelChanged() { win.show("brightness"); }
    }

    Bloom {
        anchors.fill: parent
        anchors.margins: 20
        shown: win.shown
        fromScale: 0.9
        origin: Qt.point(width, height / 2)

        Glass {
            anchors.fill: parent
            radius: width / 2
            fill: Theme.glassStrong

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                text: Math.round(win.value * 100)
                font.family: Theme.fontDisplay
                size: 23
            }

            // the track and its iridescent fill, rising from the bottom
            Item {
                id: track
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 48
                anchors.bottomMargin: 46
                width: 14

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.shell
                    border.color: Theme.hairline
                }
                Iridescent {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(width, parent.height * Math.min(1, win.value / win.max))
                    radius: width / 2
                    period: 7000
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
            }

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                name: win.icon
                size: 20
                color: Theme.ink
            }
        }
    }
}
