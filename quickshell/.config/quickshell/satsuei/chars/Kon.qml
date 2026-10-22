import QtQuick
import qs.common
import "shapes.js" as S

// Kon: a kid in a fox-ear hood in warm orange, cream in the ears, whisker
// marks on the cheeks, the hood's strings in the plate's accent, and a big
// fluffy tail with a white tip behind (the rig's `extra`). Kon hops on every
// other beat, the tail swishing.
Rig {
    id: r

    profile: ({ bob: 0.4, arms: 0.8, tilt: 0.8, extra: 1.3 })

    readonly property bool dancing: mode === "dance"
    // up on the even beats, down through the odd ones
    readonly property real hop: dancing ? Math.max(0, Math.sin(beat)) * 14 * energy : 0
    readonly property color line: Theme.at(Theme.ink, 0.35)
    readonly property color rim: Theme.at(Theme.fg, 0.22)

    Part {
        id: all
        ox: 60; oy: 150
        dy: r.bob - r.hop
        angle: r.sway

        // the tail, behind
        Part {
            angle: r.ex
            ox: 82; oy: 126
            Blob { d: "M80 132 Q120 134 117 96 Q115 78 104 86 Q110 114 78 120 Z"; fill: Style.art.fox; stroke: r.line; line: 1.2 }
            Blob { d: "M104 86 Q115 78 117 96 Q117 102 115 106 Q110 94 104 86 Z"; fill: Style.art.shine }
        }
        // legs, tucked on the hop
        Part {
            dy: r.lL - r.hop * 0.25
            Blob { d: S.rr(45, 126, 11, 22, 5); fill: Theme.hair; stroke: r.rim; line: 1.2 }
            Blob { d: S.ell(50, 150, 8, 4.5); fill: Style.art.sock }
        }
        Part {
            dy: r.lR - r.hop * 0.25
            Blob { d: S.rr(64, 126, 11, 22, 5); fill: Theme.hair; stroke: r.rim; line: 1.2 }
            Blob { d: S.ell(70, 150, 8, 4.5); fill: Style.art.sock }
        }
        Part {
            angle: r.aL
            ox: 33.5; oy: 102
            Blob { d: S.rr(27, 98, 13, 30, 6.5); fill: Style.art.fox; stroke: r.line; line: 1 }
            Blob { d: S.circ(33.5, 129, 5.5); fill: Style.art.skin }
        }
        Part {
            angle: r.aR
            ox: 86.5; oy: 102
            Blob { d: S.rr(80, 98, 13, 30, 6.5); fill: Style.art.fox; stroke: r.line; line: 1 }
            Blob { d: S.circ(86.5, 129, 5.5); fill: Style.art.skin }
        }
        // the hoodie, a cream belly
        Blob { d: "M36 98 Q60 86 84 98 L89 134 Q60 142 31 134 Z"; fill: Style.art.fox; stroke: r.line; line: 1 }
        Blob { d: "M48 110 Q60 104 72 110 L74 132 Q60 136 46 132 Z"; fill: Style.art.cream }
        Blob { d: "M55 96 v12 M65 96 v12"; stroke: Theme.accent; line: 1.8 }

        Part {
            id: head
            angle: r.tilt
            ox: 60; oy: 92

            // the hood and its ears
            Blob { d: "M28 46 L24 8 L56 30 Z M92 46 L96 8 L64 30 Z"; fill: Style.art.fox; stroke: r.line; line: 1.2 }
            Blob { d: "M31 38 L29 16 L48 30 Z M89 38 L91 16 L72 30 Z"; fill: Style.art.cream }
            Blob { d: S.ell(60, 60, 38, 36); fill: Style.art.fox; stroke: r.line; line: 1.2 }
            Blob { d: S.ell(60, 70, 27, 25); fill: Style.art.skin }
            // the fringe under the hood
            Blob { d: "M34 64 Q38 44 60 44 Q82 44 86 64 Q78 54 70 60 Q64 50 56 60 Q48 52 34 64 Z"; fill: Theme.hair }

            Part {
                ox: 60; oy: 72
                sy: r.eyes
                Blob { d: S.ell(48, 72, 5.2, 7); fill: Style.art.eye }
                Blob { d: S.ell(72, 72, 5.2, 7); fill: Style.art.eye }
                Blob { d: S.ell(48, 75, 3.9, 3.3) + S.ell(72, 75, 3.9, 3.3); fill: Theme.accent }
                Blob { d: S.circ(46.4, 69, 2) + S.circ(70.4, 69, 2); fill: Style.art.shine }
            }
            // whisker marks
            Blob { d: "M35 80 l7 1.5 M35 85 l7 0 M85 80 l-7 1.5 M85 85 l-7 0"; stroke: Style.art.mouth; line: 1.3; opacity: 0.6 }
            Blob {
                d: r.mouthOpen ? "M55.5 82 Q60 88.5 64.5 82 Z" : "M57 83 Q60 85.5 63 83"
                fill: r.mouthOpen ? Style.art.mouth : "transparent"
                stroke: Style.art.mouth
                line: 1.6
            }
        }
    }
}
