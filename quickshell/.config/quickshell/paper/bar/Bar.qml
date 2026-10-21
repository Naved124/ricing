pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The bar: a strip of ruled card taped across the top of each monitor.
// 44 tall, nearly the full width of the screen, centred 10 px from the
// top and turned a hair (−0.35°), with one blue rule 10 px above its
// bottom edge and a piece of washi tape over each end. The lamp's
// pull-chain (light and dark) hangs from the right-hand tape. It reserves
// its space, so tiled windows sit below it, and steps aside for fullscreen.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int stripHeight: 44
    readonly property int stripWidth: (screen?.width ?? 1920) - 56   // 28 px in from each edge
    readonly property int top: 10
    readonly property int pad: 40            // below: room for the tilt and the shadow
    readonly property int side: 26           // either end: room for the tape

    visible: !Hypr.fullscreenOn(monitor)

    anchors.top: true
    implicitWidth: stripWidth + side * 2
    implicitHeight: top + stripHeight + pad
    exclusiveZone: top + stripHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "paper-bar"

    // only the strip and the pull-chain take clicks; the margins around
    // them stay click-through
    mask: Region { item: strip; Region { item: lamp } }

    // caffeine: one bar holds an idle inhibitor, so hypridle neither dims,
    // locks nor sleeps while it's on
    IdleInhibitor {
        window: win
        enabled: Shell.caffeine && win.screen === Quickshell.screens[0]
    }

    Item {
        id: strip
        x: win.side
        y: win.top
        width: win.stripWidth
        height: win.stripHeight
        rotation: -0.35
        antialiasing: true

        Sheet {
            anchors.fill: parent
            seed: 44
            // one rule line, 10 px above the bottom edge
            ruled: true
            ruleTop: parent.height - 10
            ruleGap: 1000
        }

        Tape { x: -14; y: -8; rotation: -14 }
        Tape { x: parent.width - width + 14; y: -8; rotation: 11 }
        LampChain {
            id: lamp
            x: parent.width - 30
            y: parent.height - 4
        }

        // the middle: the window's title, or what's playing (Island.qml)
        Island {
            bar: win
            monitor: win.monitor
            width: parent.width * 0.36
            x: (parent.width - width) / 2
            y: (parent.height - 6 - height) / 2
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 34
            anchors.rightMargin: 34
            anchors.bottomMargin: 6
            spacing: 22

            Workspaces {
                monitor: win.monitor
                Layout.alignment: Qt.AlignVCenter
            }

            // the island sits over the middle of the strip
            Item {
                Layout.fillWidth: true
            }

            NetSpeed {
                Layout.alignment: Qt.AlignVCenter
            }

            Hand {
                Layout.alignment: Qt.AlignVCenter
                text: `cpu ~${Math.round(Cpu.usage * 100)}%`
                color: Theme.ink
            }

            Rec {
                Layout.alignment: Qt.AlignVCenter
            }

            Cell {
                Layout.alignment: Qt.AlignVCenter
                visible: Battery.present
            }

            Speaker {
                Layout.alignment: Qt.AlignVCenter
            }

            Tray {
                bar: win
                Layout.alignment: Qt.AlignVCenter
            }

            Clock {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
