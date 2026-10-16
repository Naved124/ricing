import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The bar: a floating pill, top-centre, 780 × 38, 12 px from the top.
// One per monitor, each showing that monitor's workspaces. It reserves its
// space so windows never slide under it, and steps aside for fullscreen.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int pillWidth: 780
    readonly property int pillHeight: 38
    readonly property int pad: 22          // room for the lilac shadow

    visible: !Hypr.fullscreenOn(monitor)

    anchors.top: true
    margins.top: 12
    implicitWidth: pillWidth + pad * 2
    implicitHeight: pillHeight + pad
    exclusiveZone: pillHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nacre-bar"

    // only the pill takes clicks; the shadow margin stays click-through
    mask: Region { item: pill }

    Glass {
        id: pill
        x: win.pad
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
                monitor: win.monitor
                Layout.alignment: Qt.AlignVCenter
            }

            Title {
                monitor: win.monitor
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            MediaMini {
                bar: win
                Layout.alignment: Qt.AlignVCenter
            }

            Chips {
                bar: win
                Layout.alignment: Qt.AlignVCenter
            }

            Clock {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
