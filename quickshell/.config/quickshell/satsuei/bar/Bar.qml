import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.deskwidget
import qs.services

// The bar: a floating glass pill, 46 tall, 10 from the edges, 16 round, laid
// out like the mock's three columns. On the left the seal (撮 Satsuei, which
// opens the Satsuei panel) and the episodes; in the middle the clock in Dela
// Gothic One and a dim date ("木 · 22 Oct"); on the right what's playing, the
// marks, the lock and the control centre. One per monitor; it reserves its
// space and steps aside for fullscreen.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int edge: 10
    readonly property int pillHeight: 46

    visible: !Hypr.fullscreenOn(monitor)

    anchors { top: true; left: true; right: true }
    margins.top: edge
    implicitHeight: pillHeight + 40             // the pill's shadow falls below it
    exclusiveZone: pillHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "satsuei-bar"
    mask: Region { item: pill }

    // caffeine: one bar holds an idle inhibitor, so hypridle neither dims,
    // locks nor sleeps while it's on
    IdleInhibitor {
        window: win
        enabled: Shell.caffeine && win.screen === Quickshell.screens[0]
    }

    Glass {
        id: pill
        x: win.edge
        width: win.width - win.edge * 2
        height: win.pillHeight
        radius: 16

        // left: the seal and the episodes
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Btn {
                id: studio
                height: 32
                width: sealRow.implicitWidth + 18
                on: Shell.studioOpen
                onClicked: Shell.toggleStudio()
                Row {
                    id: sealRow
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Seal { anchors.verticalCenter: parent.verticalCenter }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Satsuei"
                        weight: Style.weightStrong
                        spacing: 0.04
                    }
                }
            }
            Episodes {
                monitor: win.monitor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // middle: the clock and the date
        Row {
            anchors.centerIn: parent
            spacing: 10
            SystemClock { id: clock; precision: SystemClock.Minutes }
            Label {
                anchors.baseline: date.baseline
                text: Qt.formatTime(clock.date, "HH:mm")
                display: true
                size: 19
                spacing: 0.02
                font.features: { "tnum": 1 }
            }
            Label {
                id: date
                anchors.verticalCenter: parent.verticalCenter
                readonly property string jd: "日月火水木金土"
                text: jd[clock.date.getDay()] + " · " + Qt.formatDate(clock.date, "d MMM")
                color: Theme.fgDim
                weight: 500
            }
        }

        // Notion's Desk, just left of the status: open to-dos, the next countdown
        DeskPill {
            screenName: win.screen ? win.screen.name : ""
            showNext: win.width >= 1600
            anchors.right: status.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
        }

        // right: what's playing and the status
        Status {
            id: status
            bar: win
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
