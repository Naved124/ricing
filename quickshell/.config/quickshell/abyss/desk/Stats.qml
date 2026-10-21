pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.common
import qs.services

// The system card, as one of the reef's jellyfish, on the desktop under the
// windows: a bell of glass holding the CPU in Jura, its rim lights running
// faster the busier it is, and three tentacles hanging from it, CPU (teal),
// memory (violet) and disk (pink), each lit down its length as far as its
// value goes, swaying slowly. Drag it anywhere: it stays where it's dropped
// (Shell.statsAt, kept in shell.json); right-click puts it away and the
// control centre's "System card" brings it back. Fed by Sys (one reader).
PanelWindow {
    id: win

    screen: Quickshell.screens[0] ?? null
    readonly property var monitor: Hypr.monitorFor(screen)

    visible: Shell.statsShown && !Hypr.fullscreenOn(monitor)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "abyss-stats"

    mask: Region { item: card }

    // its own slow clock: 30 frames a second, only while it shows
    property real t: 0
    Timer {
        interval: 33
        repeat: true
        running: win.visible
        onTriggered: win.t += 0.033 * (Motion.reduced ? 0.45 : 1)
    }

    Item {
        id: card
        width: 280
        height: 330

        x: Shell.statsAt.x * (win.width - width)
        y: Shell.statsAt.y * (win.height - height)
        scale: drag.active ? 1.03 : 1
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

        // the bell pulses: a breath every few seconds, quicker with load
        readonly property real pulse: 0.5 + 0.5 * Math.sin(win.t * (0.9 + 2.2 * cpu.shown))
        readonly property real bellW: 220 * (1 - 0.04 * pulse)
        readonly property real bellH: 104 * (0.96 + 0.06 * pulse)
        readonly property real rimY: 18 + bellH

        QtObject { id: cpu; property real shown: Sys.cpu; Behavior on shown { NumberAnimation { duration: 600 } } }
        QtObject { id: mem; property real shown: Sys.mem; Behavior on shown { NumberAnimation { duration: 600 } } }
        QtObject { id: disk; property real shown: Sys.disk; Behavior on shown { NumberAnimation { duration: 600 } } }

        // its halo in the water
        Glow {
            anchors.horizontalCenter: parent.horizontalCenter
            y: card.rimY - card.bellH * 0.55 - height / 2
            width: 360; height: 300
            color: Theme.glow
            opacity: 0.14 + 0.18 * cpu.shown + (drag.active ? 0.15 : 0)
        }

        // the tentacles: CPU, memory, disk
        Repeater {
            model: [
                { name: "CPU", tint: Theme.glow, value: () => cpu.shown, at: 0.3, detail: () => `${Math.round(Sys.cpu * 100)}%` },
                { name: "MEMORY", tint: Theme.glow2, value: () => mem.shown, at: 0.5, detail: () => `${Sys.fmt(Sys.memUsed)} / ${Sys.fmt(Sys.memTotal)}` },
                { name: "DISK /", tint: Theme.pink, value: () => disk.shown, at: 0.7, detail: () => `${Sys.fmt(Sys.diskFree)} free` },
            ]
            delegate: Item {
                id: tent
                required property var modelData
                required property int index
                readonly property real x0: card.width / 2 + (modelData.at - 0.5) * card.bellW * 1.3
                readonly property real len: 150
                readonly property real lit: Math.max(0.04, Math.min(1, modelData.value()))
                anchors.fill: parent

                // a smooth sway: further out swings more, each on its own phase
                function path(upTo) {
                    const n = 14, pts = [];
                    for (let i = 0; i <= n; i++) {
                        const u = i / n * upTo, y = card.rimY - 2 + u * tent.len;
                        const x = tent.x0 + Math.sin(win.t * 0.9 + tent.index * 1.7 + u * 4.2) * 9 * u
                                  + (tent.modelData.at - 0.5) * 30 * u;
                        pts.push([x, y]);
                    }
                    let d = `M ${pts[0][0]} ${pts[0][1]}`;
                    for (let i = 1; i < pts.length - 1; i++) {
                        const mx = (pts[i][0] + pts[i + 1][0]) / 2, my = (pts[i][1] + pts[i + 1][1]) / 2;
                        d += ` Q ${pts[i][0]} ${pts[i][1]} ${mx} ${my}`;
                    }
                    const l = pts[pts.length - 1];
                    return { d: d + ` L ${l[0]} ${l[1]}`, end: l };
                }
                readonly property var whole: path(1)
                readonly property var bright: path(lit)

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // the whole tentacle, faint
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.alpha(tent.modelData.tint, 0.18)
                        strokeWidth: 2
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: tent.whole.d }
                    }
                    // its glow, as far as the value
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.alpha(tent.modelData.tint, 0.22)
                        strokeWidth: 7
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: tent.bright.d }
                    }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: tent.modelData.tint
                        strokeWidth: 2
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: tent.bright.d }
                    }
                }
                // a light where the value ends
                Glow {
                    x: tent.bright.end[0] - width / 2
                    y: tent.bright.end[1] - height / 2
                    width: 26; height: 26
                    color: tent.modelData.tint
                    opacity: 0.9
                }
                Column {
                    x: tent.whole.end[0] - width / 2
                    y: tent.whole.end[1] + 8
                    width: 90
                    spacing: 1
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tent.modelData.name
                        size: 9.5
                        weight: Theme.weightStrong
                        spacing: 0.16
                        color: tent.modelData.tint
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tent.modelData.detail()
                        size: 10.5
                        font.family: Theme.fontMono
                        color: Theme.ink
                    }
                }
            }
        }

        // the bell: a dome of glass, its rim scalloped, light pooling at its crown
        Shape {
            id: bell
            x: (card.width - card.bellW) / 2
            y: 18
            width: card.bellW
            height: card.bellH
            preferredRendererType: Shape.CurveRenderer
            readonly property real w: width
            readonly property real h: height
            ShapePath {
                strokeColor: Theme.lineOn
                strokeWidth: 1
                fillGradient: RadialGradient {
                    centerX: bell.w / 2; centerY: bell.h * 0.25
                    centerRadius: bell.w * 0.62
                    focalX: bell.w / 2; focalY: bell.h * 0.12
                    GradientStop { position: 0.0; color: Theme.glowAt(0.30) }
                    GradientStop { position: 0.6; color: Qt.alpha(Theme.deep, 0.82) }
                    GradientStop { position: 1.0; color: Qt.alpha(Theme.abyss, 0.86) }
                }
                startX: 0; startY: bell.h
                PathCubic {
                    x: bell.w; y: bell.h
                    control1X: -bell.w * 0.02; control1Y: -bell.h * 0.28
                    control2X: bell.w * 1.02; control2Y: -bell.h * 0.28
                }
                PathQuad { x: bell.w * 0.875; y: bell.h; controlX: bell.w * 0.9375; controlY: bell.h * 0.86 }
                PathQuad { x: bell.w * 0.75; y: bell.h; controlX: bell.w * 0.8125; controlY: bell.h * 0.86 }
                PathQuad { x: bell.w * 0.625; y: bell.h; controlX: bell.w * 0.6875; controlY: bell.h * 0.86 }
                PathQuad { x: bell.w * 0.5; y: bell.h; controlX: bell.w * 0.5625; controlY: bell.h * 0.86 }
                PathQuad { x: bell.w * 0.375; y: bell.h; controlX: bell.w * 0.4375; controlY: bell.h * 0.86 }
                PathQuad { x: bell.w * 0.25; y: bell.h; controlX: bell.w * 0.3125; controlY: bell.h * 0.86 }
                PathQuad { x: bell.w * 0.125; y: bell.h; controlX: bell.w * 0.1875; controlY: bell.h * 0.86 }
                PathQuad { x: 0; y: bell.h; controlX: bell.w * 0.0625; controlY: bell.h * 0.86 }
            }
        }

        // rim lights: a pulse running round the edge, faster with load
        Repeater {
            model: 9
            delegate: Glow {
                required property int index
                readonly property real a: Math.max(0, Math.sin(win.t * (2 + 6 * cpu.shown) - index * 0.7))
                x: bell.x + bell.width * index / 8 - width / 2
                y: card.rimY - height / 2
                width: 12 + 10 * a; height: width
                color: Theme.glow
                opacity: 0.25 + 0.7 * a
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18 + card.bellH * 0.28
            spacing: 0
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SYSTEM"
                size: 9.5
                weight: Theme.weightStrong
                spacing: 0.24
                color: Theme.inkDim
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${Math.round(Sys.cpu * 100)}%`
                font.family: Theme.fontDisplay
                size: 30
                weight: Theme.weightDisplay
                spacing: 0.08
                font.features: { "tnum": 1 }
            }
        }
    }
}
