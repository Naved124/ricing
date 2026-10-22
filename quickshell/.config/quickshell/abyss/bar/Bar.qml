import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// The bar: a pill of glass floating in the water, Nacre's size but 2 px thicker:
// the screen's width less the windows' outer gap a side (its ends line up
// with the windows below), 40 tall, 12 from the top, a line edge and a faint
// teal halo. The workspaces and the window's title on the left, the status
// on the right in ink-dim (its details drop below the bar on hover); the
// middle is the island's (Island.qml, a layer of its own). No clock: the
// island has it. A press anywhere on the pill stirs the water under it.
// One per monitor; it reserves its space and steps aside for fullscreen.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int side: Theme.gapsOut     // ends line up with the windows below
    readonly property int pillWidth: width - side * 2
    readonly property int pillHeight: 40
    readonly property int top: 12
    readonly property int islandHalf: 170      // half the island at its widest in the bar
    // a status detail shown under the bar: { x, text }
    property var detail: null

    visible: !Hypr.fullscreenOn(monitor)

    anchors { top: true; left: true; right: true }
    margins.top: top
    implicitHeight: pillHeight + 64            // room under the pill for a detail chip
    exclusiveZone: pillHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "abyss-bar"

    // only the pill (and a detail while it shows) takes the pointer
    mask: Region {
        item: pill
        Region { item: chip.visible ? chip : null }
    }

    // caffeine: one bar holds an idle inhibitor, so hypridle neither dims,
    // locks nor sleeps while it's on
    IdleInhibitor {
        window: win
        enabled: Shell.caffeine && win.screen === Quickshell.screens[0]
    }

    Glass {
        id: pill
        x: Math.round((win.width - width) / 2)
        width: win.pillWidth
        height: win.pillHeight
        radius: height / 2

        // any press on the bar, even one a button takes, touches the water
        PointHandler {
            id: touch
            onActiveChanged: if (active) {
                const p = touch.point.position;
                Reefs.disturb(win.screen, pill.x + p.x, win.top + p.y, 0.35);
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 12

            Workspaces {
                id: workspaces
                monitor: win.monitor
                Layout.alignment: Qt.AlignVCenter
            }
            // up to the island, with a little air
            Title {
                monitor: win.monitor
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.max(0, Math.round(Math.min(implicitWidth,
                    pill.width / 2 - win.islandHalf - workspaces.x - workspaces.width - 12)))
            }
            Item { Layout.fillWidth: true }
            Status {
                bar: win
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: pill.width / 2 - win.islandHalf - 12
            }
        }
    }

    // a detail, dropped under the bar from the hovered status item
    Glass {
        id: chip
        readonly property bool shown: !!win.detail
        visible: opacity > 0
        opacity: shown ? 1 : 0
        x: Math.round(Math.max(pill.x, Math.min(pill.x + pill.width - width, (win.detail?.x ?? 0) - width / 2)))
        y: win.pillHeight + 8 + (shown ? 0 : -6)
        width: chipText.implicitWidth + 24
        height: chipText.implicitHeight + 14
        radius: Theme.radiusChip
        fill: Theme.glassStrong
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drift } }
        Behavior on y { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
        Label {
            id: chipText
            anchors.centerIn: parent
            text: win.detail?.text ?? ""
            size: Theme.uiSize - 2
            color: Theme.ink
            lineHeight: 1.3
        }
    }
}
