import QtQuick
import qs.common
import "shapes.js" as S

// Yuki: a small pale ghost with a wavy hem, sleeve nubs and a tiny triangular
// headband in the plate's accent, and no legs. Yuki floats above the ground,
// bobbing, and dances by turning slowly round (a full turn every four beats)
// with a lazy sway.
Rig {
    id: r

    profile: ({ legs: 0, arms: 0.5, bob: 0.7, tilt: 0.6, sway: 1.8, extra: 0.5 })

    readonly property bool dancing: mode === "dance"
    readonly property real turn: dancing ? Math.cos(phase * Math.PI) : 1
    readonly property color line: Theme.at(Theme.ink, 0.3)

    Part {
        id: all
        ox: 60; oy: 96
        // always floating: a slow breath up and down over the shadow
        dy: -8 + Math.sin(r.t * 1.6) * 3 + r.bob
        angle: r.sway
        // the turn: narrow edge-on, never quite gone
        sx: Math.sign(r.turn || 1) * Math.max(0.15, Math.abs(r.turn))

        Part {
            angle: r.aL
            ox: 34; oy: 92
            Blob { d: S.ell(28, 100, 7, 10); fill: Style.art.ghost; stroke: r.line; line: 1.2 }
        }
        Part {
            angle: r.aR
            ox: 86; oy: 92
            Blob { d: S.ell(92, 100, 7, 10); fill: Style.art.ghost; stroke: r.line; line: 1.2 }
        }

        // the sheet, its hem rippling
        Blob {
            d: "M30 74 Q30 30 60 30 Q90 30 90 74 L92 136 Q86 146 80 138 Q74 148 68 138 Q62 148 56 138 Q50 148 44 138 Q38 146 30 138 Z"
            fill: Style.art.ghost
            stroke: r.line
            line: 1.4
        }
        Blob { d: "M38 120 Q40 136 44 138"; stroke: Theme.at(Theme.ink, 0.12); line: 3 }

        Part {
            id: head
            angle: r.tilt
            ox: 60; oy: 96

            // the headband: a band across the brow, the triangle at its middle
            Blob { d: "M36 46 Q60 38 84 46"; stroke: Theme.accent; line: 2.5 }
            Blob { d: "M52 46 L60 32 L68 46 Z"; fill: Theme.accent; stroke: Theme.at(Theme.ink, 0.25); line: 1 }

            Part {
                ox: 60; oy: 68
                sy: r.eyes
                Blob { d: S.ell(49, 68, 4.4, 6) + S.ell(71, 68, 4.4, 6); fill: Style.art.eye }
                Blob { d: S.circ(47.8, 65.5, 1.6) + S.circ(69.8, 65.5, 1.6); fill: Style.art.shine }
            }
            Blob { d: S.ell(41, 78, 4.5, 2.2) + S.ell(79, 78, 4.5, 2.2); fill: Style.art.blush; opacity: 0.5 }
            Blob {
                d: r.mouthOpen ? S.ell(60, 80, 3.4, 4) : "M57 80 Q60 82.5 63 80"
                fill: r.mouthOpen ? Style.art.mouth : "transparent"
                stroke: Style.art.mouth
                line: 1.5
            }
        }
    }
}
