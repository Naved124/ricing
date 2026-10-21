pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// The system card: a pane of pearl glass on the desktop, under the windows.
// Material 3's progress indicators (a gap between colour and track, round
// caps, a stop dot at the track's end) drawn in Nacre's way: the colour is
// the orient (cpu sky, memory orchid, disk mint; Black Pearl's sapphire,
// aubergine and peacock at night), the numbers in Italiana, the words in
// Manrope, the track a frost hairline.
// Drag it anywhere: an iridescent rim shows while it's held, and it stays
// where it's dropped (Shell.statsAt, kept in shell.json). Right-click puts
// it away; the control centre's "System card" tile brings it back.
PanelWindow {
    id: win

    screen: Quickshell.screens[0] ?? null
    readonly property var monitor: Hypr.monitorFor(screen)

    visible: Shell.statsShown && !Hypr.fullscreenOn(monitor)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nacre-stats"

    mask: Region { item: card }

    // the pastels wash out on light glass: by day each one is taken 40%
    // towards ink; at night Black Pearl's orient stands as it is
    function deep(c) { return Theme.mode.mix(c, Theme.ink, 0.4 * (1 - Theme.k)); }

    // Material 3's circular indicator, in one orient colour
    component Dial: Item {
        id: dial
        property real value: 0                  // 0..1
        property color tint: Theme.sky
        property string label: ""
        property string detail: ""

        property real shown: value
        Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }

        readonly property real r: 33
        readonly property real pen: 7
        readonly property real gap: (4 + pen) / r * 180 / Math.PI
        readonly property real sweep: Math.max(0.001, Math.min(1, shown)) * 360

        width: 112
        height: 132

        Shape {
            id: ring
            width: 2 * (dial.r + dial.pen)
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(dial.tint, 0.2)
                strokeWidth: dial.pen
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2; centerY: ring.height / 2
                    radiusX: dial.r; radiusY: dial.r
                    startAngle: -90 + dial.sweep + dial.gap
                    sweepAngle: Math.max(0, 360 - dial.sweep - 2 * dial.gap)
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: dial.tint
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
        Text {
            anchors.centerIn: ring
            text: `${Math.round(dial.value * 100)}%`
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.weight: Theme.weightDisplay
            font.pixelSize: 25
        }
        Label {
            id: name
            anchors.top: ring.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.label
            size: Theme.uiSize
            weight: Theme.weightStrong
            color: Theme.fg
        }
        Label {
            anchors.top: name.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.detail
            size: Theme.uiSize - 2
            color: Theme.muted
        }
    }

    Item {
        id: card
        width: 300
        height: 262

        x: Shell.statsAt.x * (win.width - width)
        y: Shell.statsAt.y * (win.height - height)
        scale: drag.active ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durPanelIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

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

        Glass {
            id: pane
            anchors.fill: parent
            anchors.margins: 10
            radius: 28                      // Material 3's extra-large corner

            Label {
                x: 22; y: 16
                text: "System"
                size: Theme.uiSize + 3
                weight: Theme.weightStrong
                color: Theme.fg
            }

            Row {
                x: (pane.width - width) / 2
                y: 48
                spacing: 16
                Dial {
                    value: Sys.cpu
                    tint: win.deep(Theme.gradient[1])
                    label: "CPU"
                }
                Dial {
                    value: Sys.mem
                    tint: win.deep(Theme.gradient[4])
                    label: "Memory"
                    detail: `${Sys.fmt(Sys.memUsed)} / ${Sys.fmt(Sys.memTotal)}`
                }
            }

            // the disk: Material 3's linear indicator
            Item {
                id: disk
                x: 22
                y: 186
                width: pane.width - 44
                height: 50

                property real shown: Sys.disk
                Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.bloom } }
                readonly property real bar: 8
                readonly property color tint: win.deep(Theme.gradient[2])

                Label {
                    id: diskName
                    text: "Disk  /"
                    size: Theme.uiSize
                    weight: Theme.weightStrong
                    color: Theme.fg
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: diskName.verticalCenter
                    text: `${Sys.fmt(Sys.diskFree)} free`
                    size: Theme.uiSize - 1
                    color: Theme.fg
                }
                Item {
                    id: strip
                    y: 24
                    width: parent.width
                    height: disk.bar
                    Rectangle {
                        id: usedPart
                        width: Math.max(disk.bar, disk.shown * parent.width)
                        height: parent.height
                        radius: height / 2
                        color: disk.tint
                    }
                    Rectangle {
                        x: usedPart.width + 4
                        width: Math.max(0, parent.width - x)
                        height: parent.height
                        radius: height / 2
                        color: Qt.alpha(disk.tint, 0.22)
                        visible: width > height
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4; radius: 2
                        color: disk.tint
                    }
                }
                Label {
                    anchors.top: strip.bottom
                    anchors.topMargin: 4
                    text: `${Sys.fmt(Sys.diskUsed)} used of ${Sys.fmt(Sys.diskTotal)}`
                    size: Theme.uiSize - 2
                    color: Theme.muted
                }
            }
        }

        // held: the orient runs round the edge
        Iridescent {
            anchors.fill: pane
            radius: pane.radius
            ring: 2
            opacity: drag.active ? 0.9 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
    }
}
