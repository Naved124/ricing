pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// Volume and brightness: a slim depth gauge at the right edge, a column of
// glass the level fills with teal light, tiny plankton rising inside it
// while it changes. Up to 150% for the volume: past the 100% mark the light
// runs violet. It touches the water beside it when it changes, appears
// when either changes and drifts away 1.2 s later.
PanelWindow {
    id: win

    property string kind: "volume"     // "volume" | "brightness"
    property bool shown: false
    property bool armed: false         // ignore the first values at startup
    property bool moving: false

    readonly property real value: kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.level
    readonly property real max: kind === "volume" ? Audio.maxVolume : 1
    readonly property string icon: kind === "volume" ? Audio.icon : "brightness"
    readonly property int gaugeHeight: 240

    function show(k) {
        if (!armed) return;
        kind = k;
        shown = true;
        moving = true;
        hideTimer.restart();
        stillTimer.restart();
        // the gauge's foot, where its light meets the water
        Reefs.disturb(win.screen, win.screen.width - 40, win.screen.height / 2 + gaugeHeight / 2, 0.35);
    }

    screen: Hypr.focusedScreen
    anchors.right: true
    margins.right: 14
    implicitWidth: 44 + 40
    implicitHeight: gaugeHeight + 40
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "abyss-osd"
    mask: Region {}

    Timer { interval: 1500; running: true; onTriggered: win.armed = true }
    Timer { id: hideTimer; interval: 1200; onTriggered: win.shown = false }
    Timer { id: stillTimer; interval: 500; onTriggered: win.moving = false }

    // qs -c abyss ipc call osd trigger volume|brightness
    IpcHandler {
        target: "osd"
        function trigger(kind: string): void { win.show(kind); }
    }
    Connections {
        target: Audio
        function onVolumeChanged() { win.show("volume"); }
        function onMutedChanged() { win.show("volume"); }
    }
    Connections {
        target: Brightness
        function onLevelChanged() { win.show("brightness"); }
    }

    Item {
        id: gauge
        x: 20
        y: 20
        width: 44
        height: win.gaugeHeight
        opacity: win.shown ? 1 : 0
        transform: Translate { x: win.shown ? 0 : 16 }
        Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.durPanelIn : Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.settle : Theme.sink } }

        Glass {
            anchors.fill: parent
            radius: width / 2
            fill: Theme.glassStrong
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 12
            text: Math.round(win.value * 100)
            font.family: Theme.fontMono
            size: 12
            color: win.value > 1 ? Theme.glow2 : Theme.ink
        }

        // the column: glass, the light rising in it
        Item {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 38
            anchors.bottomMargin: 40
            width: 10
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.wash
                border.color: Theme.line
            }
            Item {
                id: light
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(width, parent.height * Math.min(1, win.value / win.max))
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: win.value > 1 ? Theme.glow2 : Theme.glow }
                        GradientStop { position: 1; color: Theme.glowAt(0.55) }
                    }
                }
                Specks {
                    anchors.fill: parent
                    count: 7
                    size: 1.6
                    color: Theme.ink
                    running: win.moving
                    opacity: win.moving ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }
            }
            // where 100% sits
            Rectangle {
                visible: win.max > 1
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * (1 - 1 / win.max)
                width: parent.width + 6
                height: 1
                color: Theme.inkDim
            }
        }
        // the light's glow at its surface
        Glow {
            anchors.horizontalCenter: parent.horizontalCenter
            y: column.y + column.height - light.height - height / 2
            width: 44; height: 44
            color: win.value > 1 ? Theme.glow2 : Theme.glow
            opacity: 0.7
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }
        }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            name: win.icon
            size: 16
            color: Theme.inkDim
        }
    }
}
