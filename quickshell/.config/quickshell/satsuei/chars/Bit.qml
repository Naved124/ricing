import QtQuick
import qs.common
import qs.services
import "shapes.js" as S

// Bit: a small robot, its rounded body in the plate's second accent, a light
// head with a dark screen for a face, eyes of glowing accent and an antenna
// ball (the rig's `extra`). It dances stiffly: every pose held for a quarter
// of a beat, the ball flashing on each kick and the eyes turning to ^ ^ on
// the downbeat.
Rig {
    id: r

    profile: ({ steps: 4, bob: 0.8, tilt: 1.2, sway: 1.4, arms: 0.9, legs: 0.6, extra: 0.6 })

    readonly property bool dancing: mode === "dance"
    readonly property bool kick: dancing && Tempo.kick > 0.55
    // the first quarter of each beat
    readonly property bool downbeat: dancing && (beat / Math.PI) % 1 < 0.25
    readonly property color line: Theme.at(Theme.ink, 0.4)

    Part {
        id: all
        ox: 60; oy: 152
        dy: r.bob
        angle: r.sway

        Part {
            dy: r.lL
            Blob { d: S.rr(44, 130, 12, 18, 4); fill: Style.art.robot; stroke: r.line; line: 1 }
            Blob { d: S.rr(40, 146, 20, 8, 4); fill: Style.art.screen }
        }
        Part {
            dy: r.lR
            Blob { d: S.rr(64, 130, 12, 18, 4); fill: Style.art.robot; stroke: r.line; line: 1 }
            Blob { d: S.rr(60, 146, 20, 8, 4); fill: Style.art.screen }
        }
        Part {
            angle: r.aL
            ox: 33; oy: 102
            Blob { d: S.rr(27, 98, 12, 26, 6); fill: Style.art.robot; stroke: r.line; line: 1 }
            Blob { d: S.circ(33, 127, 5); fill: Theme.accent2 }
        }
        Part {
            angle: r.aR
            ox: 87; oy: 102
            Blob { d: S.rr(81, 98, 12, 26, 6); fill: Style.art.robot; stroke: r.line; line: 1 }
            Blob { d: S.circ(87, 127, 5); fill: Theme.accent2 }
        }
        // the body: a rounded box with a panel and two lights
        Blob { d: S.rr(36, 94, 48, 42, 12); fill: Theme.accent2; stroke: r.line; line: 1 }
        Blob { d: S.rr(46, 104, 28, 18, 5); fill: Theme.at(Style.art.screen, 0.55) }
        Blob { d: S.circ(54, 113, 2.4); fill: Theme.accent; opacity: r.kick ? 1 : 0.45 }
        Blob { d: S.circ(66, 113, 2.4); fill: Theme.accent; opacity: r.kick ? 0.45 : 1 }

        Part {
            id: head
            angle: r.tilt
            ox: 60; oy: 94

            // the antenna, its ball flashing on the kick
            Part {
                angle: r.ex
                ox: 60; oy: 30
                Blob { d: "M60 30 L60 14"; stroke: Style.art.robot; line: 3 }
                Blob { d: S.circ(60, 11, 9); fill: Theme.accent; opacity: r.kick ? 0.35 : 0 }
                Blob { d: S.circ(60, 11, 5); fill: r.kick ? Theme.accent : Theme.accent2; stroke: r.line; line: 1 }
            }
            Blob { d: S.rr(22, 28, 76, 66, 22); fill: Style.art.robot; stroke: r.line; line: 1.2 }
            Blob { d: S.rr(16, 52, 8, 18, 4) + S.rr(96, 52, 8, 18, 4); fill: Theme.accent2 }
            Blob { d: S.rr(30, 40, 60, 44, 14); fill: Style.art.screen }

            // eyes: glowing bars, or ^ ^ on the downbeat
            Part {
                ox: 60; oy: 60
                sy: r.eyes
                visible: !r.downbeat
                Blob { d: S.rr(39, 51, 14, 18, 5) + S.rr(67, 51, 14, 18, 5); fill: Theme.accent; opacity: 0.3 }
                Blob { d: S.rr(41, 53, 10, 14, 4) + S.rr(69, 53, 10, 14, 4); fill: Theme.accent }
            }
            Blob {
                visible: r.downbeat
                d: "M40 64 L46 56 L52 64 M68 64 L74 56 L80 64"
                stroke: Theme.accent
                line: 3
            }
            Blob {
                d: r.mouthOpen ? S.rr(54, 72, 12, 5, 2.5) : "M55 74 L65 74"
                fill: r.mouthOpen ? Theme.accent : "transparent"
                stroke: Theme.accent
                line: 1.6
                opacity: 0.8
            }
        }
    }
}
