pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.services

// The volume and brightness OSD: a glass capsule under the menu bar, as in
// Tahoe, its level to 150% for sound (the part past 100% in the accent).
// It shows on its own when either changes, and on `osd trigger`.
PanelWindow {
    id: root

    property string kind: "volume"
    property bool shown: false
    readonly property real level: kind === "volume" ? Audio.volume : Brightness.level
    readonly property real max: kind === "volume" ? Audio.maxVolume : 1

    function show(k) { kind = k; shown = true; hide.restart(); }
    Timer { id: hide; interval: 1500; onTriggered: root.shown = false }
    Connections {
        target: Audio
        function onVolumeChanged() { if (Audio.ready) root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
    }
    Connections { target: Brightness; function onLevelChanged() { root.show("brightness"); } }
    IpcHandler {
        target: "osd"
        function trigger(kind: string): void { root.show(kind || "volume"); }
    }

    anchors { top: true; right: true }
    margins { top: 40; right: 14 }
    implicitWidth: 300
    implicitHeight: 70
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "goldengate:osd"
    color: "transparent"
    visible: shown || pane.opacity > 0.01
    mask: Region {}

    GlassPane {
        id: pane
        anchors { fill: parent; margins: 8 }
        radius: height / 2
        screen: root.screen
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fadeMs } }
        Label {
            id: glyph
            x: 16; anchors.verticalCenter: parent.verticalCenter
            text: root.kind === "volume" ? (Audio.muted ? "🔇" : "🔊") : "☀"
        }
        Rectangle {
            id: track
            anchors { left: glyph.right; leftMargin: 12; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            height: 8; radius: 4
            color: Theme.fill
            clip: true
            Rectangle {
                width: parent.width * Math.min(1, root.level / root.max)
                height: parent.height; radius: 4
                color: root.level > 1.001 ? Theme.accent : Theme.label
                Behavior on width { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }
            }
            // where 100% is, when sound can go past it
            Rectangle { visible: root.max > 1; x: parent.width / root.max; width: 1; height: parent.height; color: Theme.separator }
        }
    }
}
