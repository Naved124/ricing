pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The system card: an index card taped to the desk, under the windows, with
// the machine's pulse pencilled on it. Two dials (cpu in red pen, memory in
// gel ink) and a strip for the disk, shaded in pencil where it's used. Laid
// out like Material 3's progress indicators (a gap between ink and track, a
// stop dot at the track's end) but drawn in Paper's inks and hands, so it
// follows the lamp like everything else.
// Drag it anywhere: it straightens and lifts while held and is left where
// it's dropped (Shell.statsAt, kept in shell.json). Right-click puts it
// away; the control centre's "system card" brings it back.
PanelWindow {
    id: win

    screen: Quickshell.screens[0] ?? null
    readonly property var monitor: Hypr.monitorFor(screen)

    visible: Shell.statsShown && !Hypr.fullscreenOn(monitor)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "paper-stats"

    mask: Region { item: card }

    // a dial: Material 3's circular indicator in ink on a pencilled track
    component Dial: Item {
        id: dial
        property real value: 0                  // 0..1
        property color ink: Theme.red
        property string label: ""
        property string detail: ""

        property real shown: value
        Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        readonly property real r: 31
        readonly property real pen: 6
        // the gap either side of the ink, in degrees: 4 px plus the round caps
        readonly property real gap: (4 + pen) / r * 180 / Math.PI
        readonly property real sweep: Math.max(0.001, Math.min(1, shown)) * 360

        width: 96
        height: 128

        Shape {
            id: ring
            width: 2 * (dial.r + dial.pen)
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            preferredRendererType: Shape.CurveRenderer
            // the track: what's left of the circle, in pencil
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(Theme.pencil, 0.35)
                strokeWidth: dial.pen
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2; centerY: ring.height / 2
                    radiusX: dial.r; radiusY: dial.r
                    startAngle: -90 + dial.sweep + dial.gap
                    sweepAngle: Math.max(0, 360 - dial.sweep - 2 * dial.gap)
                }
            }
            // the ink
            ShapePath {
                fillColor: "transparent"
                strokeColor: dial.ink
                strokeWidth: dial.pen
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2; centerY: ring.height / 2
                    radiusX: dial.r; radiusY: dial.r
                    startAngle: -90
                    sweepAngle: dial.sweep
                }
            }
        }
        Type {
            anchors.centerIn: ring
            text: `${Math.round(dial.value * 100)}%`
            size: 17
            weight: 700
        }
        Hand {
            id: name
            anchors.top: ring.bottom
            anchors.topMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.label
            size: 18
        }
        Type {
            anchors.top: name.bottom
            anchors.topMargin: -2
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.detail
            size: 11
            color: Theme.graphite
        }
    }

    Item {
        id: card
        width: 300
        height: 270

        property bool held: drag.active
        x: Shell.statsAt.x * (win.width - width)
        y: Shell.statsAt.y * (win.height - height)

        DragHandler {
            id: drag
            cursorShape: Qt.ClosedHandCursor
            xAxis.minimum: 0; xAxis.maximum: win.width - card.width
            yAxis.minimum: 0; yAxis.maximum: win.height - card.height
            onActiveChanged: if (!active) {
                Shell.setStatsAt(card.x / Math.max(1, win.width - card.width),
                                 card.y / Math.max(1, win.height - card.height));
                card.x = Qt.binding(() => Shell.statsAt.x * (win.width - card.width));
                card.y = Qt.binding(() => Shell.statsAt.y * (win.height - card.height));
            }
        }
        HoverHandler { cursorShape: Qt.OpenHandCursor }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: Shell.setStatsShown(false)
        }

        Sheet {
            id: sheet
            anchors.fill: parent
            anchors.margins: 8
            seed: 7
            tilt: card.held ? 0 : -1
            lifted: card.held
            ruled: true
            ruleTop: 196
            ruleGap: 24
            Behavior on tilt { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drop } }

            Hand {
                x: 18; y: 10
                text: "this machine"
                size: 19
                weight: 700
                color: Theme.ink
            }

            Row {
                x: 18; y: 42
                spacing: 34
                Dial {
                    value: Sys.cpu
                    ink: Theme.red
                    label: "cpu"
                }
                Dial {
                    value: Sys.mem
                    ink: Theme.accent
                    label: "memory"
                    detail: `${Sys.fmt(Sys.memUsed)} / ${Sys.fmt(Sys.memTotal)}`
                }
            }

            // the disk: Material 3's linear indicator, the used part shaded in pencil
            Item {
                id: disk
                x: 18; y: 178
                width: sheet.width - 36
                height: 60

                property real shown: Sys.disk
                Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                readonly property real bar: 10
                readonly property real used: Math.max(disk.bar, disk.shown * width)

                Hand {
                    id: diskName
                    text: "disk /"
                    size: 18
                }
                Type {
                    anchors.right: parent.right
                    anchors.baseline: diskName.baseline
                    text: `${Sys.fmt(Sys.diskFree)} free`
                    size: 13
                    weight: 700
                    color: Theme.ink
                }

                Item {
                    id: strip
                    y: 28
                    width: parent.width
                    height: disk.bar

                    // the used part: an inked outline, hatched inside
                    Rectangle {
                        id: usedPart
                        width: disk.used
                        height: parent.height
                        radius: height / 2
                        color: "transparent"
                        border.color: Theme.graphite
                        border.width: 1.2
                        clip: true
                        Hatch {
                            anchors.fill: parent
                            color: Theme.graphite
                            gap: 4
                        }
                    }
                    // the rest, after a gap, and the stop dot at its end
                    Rectangle {
                        x: usedPart.width + 4
                        width: Math.max(0, parent.width - x)
                        height: parent.height
                        radius: height / 2
                        color: Qt.alpha(Theme.pencil, 0.22)
                        visible: width > height
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4; radius: 2
                        color: Theme.graphite
                    }
                }

                Type {
                    anchors.top: strip.bottom
                    anchors.topMargin: 6
                    text: `${Sys.fmt(Sys.diskUsed)} used of ${Sys.fmt(Sys.diskTotal)}`
                    size: 11
                    color: Theme.graphite
                }
            }
        }

        Tape {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -2
            width: 76
            rotation: -4
        }
    }
}
