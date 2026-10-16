pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The bar: a strip of ruled card taped across the top of each monitor.
// 44 tall, about three quarters of the screen wide, centred 10 px from the
// top and turned a hair (−0.35°), with one blue rule 10 px above its
// bottom edge and a piece of washi tape over each end. It reserves its
// space, so tiled windows sit below it, and steps aside for fullscreen.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int stripHeight: 44
    readonly property int stripWidth: Math.round((screen?.width ?? 1920) * 0.75)
    readonly property int top: 10
    readonly property int pad: 40            // room for the tape, the tilt and the shadow

    visible: !Hypr.fullscreenOn(monitor)

    anchors.top: true
    implicitWidth: stripWidth + pad * 2
    implicitHeight: top + stripHeight + pad
    exclusiveZone: top + stripHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "paper-bar"

    // only the strip takes clicks; the margins around it stay click-through
    mask: Region { item: strip }

    // caffeine: one bar holds an idle inhibitor, so hypridle neither dims,
    // locks nor sleeps while it's on
    IdleInhibitor {
        window: win
        enabled: Shell.caffeine && win.screen === Quickshell.screens[0]
    }

    Item {
        id: strip
        x: win.pad
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

        Tape { x: -26; y: -8; rotation: -14 }
        Tape { x: parent.width - width + 26; y: -8; rotation: 11 }

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

            Title {
                monitor: win.monitor
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Hand {
                Layout.alignment: Qt.AlignVCenter
                text: `cpu ~${Math.round(Cpu.usage * 100)}%`
                color: Theme.ink
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
