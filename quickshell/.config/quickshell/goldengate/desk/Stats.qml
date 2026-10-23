pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The system card: a desktop widget (CPU, memory and disk as rings), on
// the bottom layer, draggable, its place kept as fractions of the screen;
// it steps aside for a full-screen window.
PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "goldengate:widgets"
    color: "transparent"
    visible: Shell.statsShown && !Hypr.fullscreenOn(Hypr.monitorFor(screen))
    mask: Region { item: card }

    GlassPane {
        id: card
        width: 330; height: 150
        x: Shell.statsAt.x * (root.width - width)
        y: Shell.statsAt.y * (root.height - height)
        screen: root.screen
        DragHandler {
            target: card
            onActiveChanged: if (!active) Shell.moveStats(card.x / Math.max(1, root.width - card.width), card.y / Math.max(1, root.height - card.height))
        }
        Row {
            anchors.centerIn: parent
            spacing: 26
            Repeater {
                model: [
                    { name: qsTr("CPU"), v: Sys.cpu, color: Theme.blue },
                    { name: qsTr("Memory"), v: Sys.mem, color: Theme.green },
                    { name: qsTr("Disk"), v: Sys.disk, color: Theme.orange },
                ]
                delegate: Column {
                    required property var modelData
                    spacing: 6
                    Canvas {
                        id: ring
                        width: 72; height: 72
                        property real v: parent.modelData.v
                        property color tint: parent.modelData.color
                        property color track: Theme.fill
                        onVChanged: requestPaint()
                        onTintChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.lineWidth = 8;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = track;
                            ctx.beginPath(); ctx.arc(36, 36, 30, 0, 2 * Math.PI); ctx.stroke();
                            ctx.strokeStyle = tint;
                            ctx.beginPath(); ctx.arc(36, 36, 30, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.01, Math.min(1, v))); ctx.stroke();
                        }
                        Label { anchors.centerIn: parent; text: Math.round(ring.v * 100) + "%"; strong: true; font.pixelSize: Theme.smallSize + 1 }
                    }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.name; secondary: true; font.pixelSize: Theme.smallSize }
                }
            }
        }
    }
}
