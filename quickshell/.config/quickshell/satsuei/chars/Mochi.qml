import QtQuick
import qs.common
import "shapes.js" as S

// Mochi: a round cat-blob in cream with a calico patch (and one ear) in the
// plate's accent, a little scarf in its second accent and an ω mouth. Its
// tail is the rig's `extra`. It dances side to side, squashing and
// stretching on every beat (0.92 ↔ 1.06), its tail swishing.
Rig {
    id: r

    profile: ({ arms: 0.35, legs: 0.5, bob: 0.5, tilt: 0.6, sway: 2.2, extra: 1.8 })

    readonly property bool dancing: mode === "dance"
    readonly property color line: Theme.at(Theme.ink, 0.35)

    Part {
        id: all
        ox: 60; oy: 152
        dx: r.dancing ? Math.sin(r.beat) * 5 * r.energy : 0
        dy: r.bob
        angle: r.sway
        sy: r.dancing ? 0.99 + 0.07 * Math.sin(r.beat * 2) * r.energy : 1
        sx: 2 - sy

        // the tail, behind
        Part {
            angle: r.ex
            ox: 96; oy: 128
            Blob { d: "M94 132 Q124 124 114 92 Q110 82 104 90 Q114 114 92 120 Z"; fill: Style.art.cream; stroke: r.line; line: 1.2 }
            Blob { d: "M104 90 Q110 82 114 92 Q116 100 115 104 Q109 96 104 90 Z"; fill: Theme.accent }
        }
        // feet
        Part {
            dy: r.lL
            Blob { d: S.ell(46, 151, 10, 5); fill: Style.art.cream; stroke: r.line; line: 1.2 }
        }
        Part {
            dy: r.lR
            Blob { d: S.ell(74, 151, 10, 5); fill: Style.art.cream; stroke: r.line; line: 1.2 }
        }

        Part {
            id: head
            angle: r.tilt
            ox: 60; oy: 140

            // ears (the left calico), then the blob
            Blob { d: "M28 70 L32 36 L54 56 Z"; fill: Theme.accent; stroke: r.line; line: 1.2 }
            Blob { d: "M92 70 L88 36 L66 56 Z"; fill: Style.art.cream; stroke: r.line; line: 1.2 }
            Blob { d: "M90 64 L87 44 L74 56 Z"; fill: Style.art.blush; opacity: 0.6 }
            Blob { d: S.ell(60, 104, 44, 48); fill: Style.art.cream; stroke: r.line; line: 1.4 }
            Blob { d: "M22 92 Q24 62 50 58 Q60 70 50 82 Q38 90 22 92 Z"; fill: Theme.accent }

            Part {
                ox: 60; oy: 94
                sy: r.eyes
                Blob { d: S.ell(46, 94, 4.6, 5.6) + S.ell(74, 94, 4.6, 5.6); fill: Style.art.eye }
                Blob { d: S.circ(44.8, 92, 1.7) + S.circ(72.8, 92, 1.7); fill: Style.art.shine }
            }
            Blob { d: S.ell(36, 104, 5, 2.4) + S.ell(84, 104, 5, 2.4); fill: Style.art.blush; opacity: 0.55 }
            // the ω mouth, open when it sings
            Blob {
                d: r.mouthOpen ? "M53 104 Q56.5 112 60 105 Q63.5 112 67 104 Q60 110 53 104 Z"
                               : "M53 104 Q56.5 109 60 104 Q63.5 109 67 104"
                fill: r.mouthOpen ? Style.art.mouth : "transparent"
                stroke: Style.art.mouth
                line: 1.5
            }
            // whiskers
            Blob { d: "M20 100 l12 2 M20 106 l12 0 M100 100 l-12 2 M100 106 l-12 0"; stroke: r.line; line: 1 }

            // the scarf, its end hanging on the right
            Blob { d: "M24 118 Q60 134 96 118 L95 128 Q60 144 25 128 Z"; fill: Theme.accent2 }
            Blob { d: "M76 128 L84 146 L74 144 L70 130 Z"; fill: Theme.accent2 }
            Blob { d: "M26 120 Q60 135 94 120"; stroke: Theme.at(Style.art.shine, 0.35); line: 1.2 }
        }

        // paws, in front
        Part {
            angle: r.aL
            ox: 36; oy: 126
            Blob { d: S.ell(32, 134, 8, 7); fill: Style.art.cream; stroke: r.line; line: 1.2 }
        }
        Part {
            angle: r.aR
            ox: 84; oy: 126
            Blob { d: S.ell(88, 134, 8, 7); fill: Style.art.cream; stroke: r.line; line: 1.2 }
        }
    }
}
