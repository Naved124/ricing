import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.common
import qs.deskwidget
import qs.services

// The bar: a floating pill across the top, 38 tall, 12 px down, its ends
// lined up with the window gaps. The window's title follows the workspaces;
// the middle is left to the island (Island.qml, a layer of its own).
// One per monitor, each showing that monitor's workspaces. It reserves its
// space so windows never slide under it, and steps aside for fullscreen.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int side: Theme.gapsOut   // ends line up with the windows below
    readonly property int pillWidth: width - side * 2
    readonly property int pillHeight: 38
    readonly property int pad: 22          // room for the lilac shadow below
    readonly property int islandHalf: 250  // half the island at its widest (playing, hovered)

    visible: !Hypr.fullscreenOn(monitor)

    anchors { top: true; left: true; right: true }
    margins.top: 12
    implicitHeight: pillHeight + pad
    exclusiveZone: pillHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nacre-bar"

    // only the pill takes clicks; the shadow margin stays click-through
    mask: Region { item: pill }

    // caffeine: one bar holds an idle inhibitor, so hypridle neither dims,
    // locks nor sleeps while it's on
    IdleInhibitor {
        window: win
        enabled: Shell.caffeine && win.screen === Quickshell.screens[0]
    }

    Glass {
        id: pill
        x: win.side
        y: 0
        width: win.pillWidth
        height: win.pillHeight
        radius: height / 2
        shadowBlur: 0.7

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 10

            Orb {
                bar: win
                Layout.alignment: Qt.AlignVCenter
            }

            Workspaces {
                id: workspaces
                monitor: win.monitor
                Layout.alignment: Qt.AlignVCenter
            }

            // up to the island's widest, with a little air
            Title {
                monitor: win.monitor
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.max(0, Math.round(Math.min(implicitWidth, pill.width / 2 - win.islandHalf - workspaces.x - workspaces.width - 10)))
            }

            // the island sits over the middle of the pill
            Item {
                Layout.fillWidth: true
            }

            // Notion's Desk: open to-dos and the next countdown
            DeskPill {
                screenName: win.screen ? win.screen.name : ""
                Layout.alignment: Qt.AlignVCenter
            }

            NetSpeed {
                Layout.alignment: Qt.AlignVCenter
            }

            Chips {
                bar: win
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
