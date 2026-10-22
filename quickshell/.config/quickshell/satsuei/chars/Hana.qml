import QtQuick
import QtQuick.Shapes
import qs.common
import "shapes.js" as S

// Hana, the mock's character: a bob cut in the plate's hair colour with an
// ahoge, headphones in the accent, an oversized hoodie in the second accent.
// She dances with bouncy arm pumps.
Rig {
    id: r

    profile: ({ arms: 1.1, bob: 1.15, extra: 1.2 })

    Part {
        id: all
        dy: r.bob
        angle: r.sway
        ox: 60; oy: 150

        // legs, then arms, behind the hoodie
        Part {
            dy: r.lL
            Blob { d: S.rr(45, 126, 11, 22, 5); fill: Theme.hair; stroke: Theme.at(Theme.fg, 0.22); line: 1.2 }
            Blob { d: S.ell(50, 150, 8, 4.5); fill: Style.art.sock }
        }
        Part {
            dy: r.lR
            Blob { d: S.rr(64, 126, 11, 22, 5); fill: Theme.hair; stroke: Theme.at(Theme.fg, 0.22); line: 1.2 }
            Blob { d: S.ell(70, 150, 8, 4.5); fill: Style.art.sock }
        }
        Part {
            angle: r.aL
            ox: 33.5; oy: 102
            Blob { d: S.rr(27, 98, 13, 30, 6.5); fill: Theme.accent2 }
            Blob { d: S.circ(33.5, 129, 5.5); fill: Style.art.skin }
        }
        Part {
            angle: r.aR
            ox: 86.5; oy: 102
            Blob { d: S.rr(80, 98, 13, 30, 6.5); fill: Theme.accent2 }
            Blob { d: S.circ(86.5, 129, 5.5); fill: Style.art.skin }
        }

        // the hoodie, shaded toward its hem, its pocket and drawstrings
        Blob { d: "M36 98 Q60 86 84 98 L89 134 Q60 142 31 134 Z"; fill: Theme.accent2 }
        Blob {
            d: "M36 98 Q60 86 84 98 L89 134 Q60 142 31 134 Z"
            opacity: 0.5
            gradient: LinearGradient {
                y1: 88; y2: 140
                GradientStop { position: 0.4; color: Theme.at(Theme.ink, 0) }
                GradientStop { position: 1; color: Theme.at(Theme.ink, 0.45) }
            }
        }
        Blob { d: "M50 120 h20 v8 q-10 4 -20 0z"; fill: Theme.at(Theme.ink, 0.12) }
        Blob { d: "M55 96 v10 M65 96 v10"; stroke: Style.art.shine; line: 1.6; opacity: 0.8 }

        Part {
            id: head
            angle: r.tilt
            ox: 60; oy: 92

            // the hair is the plate's darkest, a little up; a faint rim of
            // light keeps it off the dark glass behind (the fill again on top
            // leaves only the stroke's outer half)
            Blob {
                d: S.ell(60, 58, 38, 36) + "M24 58 Q20 80 30 92 L36 70Z M96 58 Q100 80 90 92 L84 70Z"
                fill: Theme.hair
                stroke: Theme.at(Theme.fg, 0.22)
                line: 1.4
            }
            Blob { d: S.ell(60, 58, 38, 36) + "M24 58 Q20 80 30 92 L36 70Z M96 58 Q100 80 90 92 L84 70Z"; fill: Theme.hair }
            Blob { d: S.ell(60, 66, 29, 27); fill: Style.art.skin }

            Part {
                ox: 60; oy: 68
                sy: r.eyes
                Blob { d: S.ell(48, 68, 5.6, 7.6) + S.ell(72, 68, 5.6, 7.6); fill: Style.art.eye }
                Blob { d: S.ell(48, 71.5, 4.2, 3.6) + S.ell(72, 71.5, 4.2, 3.6); fill: Theme.accent }
                Blob {
                    d: S.circ(46.2, 65, 2.2) + S.circ(70.2, 65, 2.2) + S.circ(50, 71, 0.9) + S.circ(74, 71, 0.9)
                    fill: Style.art.shine
                }
            }
            Blob { d: S.ell(40, 78, 5, 2.4) + S.ell(80, 78, 5, 2.4); fill: Style.art.blush; opacity: 0.55 }
            Blob {
                d: r.mouthOpen ? "M55.5 78.5 Q60 85 64.5 78.5 Z" : "M56.5 79 Q60 82.5 63.5 79"
                fill: r.mouthOpen ? Style.art.mouth : "transparent"
                stroke: Style.art.mouth
                line: 1.6
            }

            // the bob's fringe, a light on it, the ahoge
            Blob {
                d: "M23 62 Q24 25 60 23 Q96 25 97 62 Q90 47 81 51 Q76 38 67 48 Q61 36 53 48 Q45 38 39 51 Q30 47 23 62Z"
                fill: Theme.hair
            }
            Blob { d: "M44 34 Q52 28 62 30"; stroke: Theme.at(Style.art.shine, 0.28); line: 2.5 }
            Part {
                angle: r.ex
                ox: 62; oy: 25
                Blob { d: "M60 25 Q63 8 76 10 Q66 13 63 26Z"; fill: Theme.hair; stroke: Theme.at(Theme.fg, 0.22); line: 1.2 }
            }

            // headphones
            Blob { d: "M25 56 Q60 2 95 56"; stroke: Theme.accent; line: 5 }
            Blob { d: S.rr(17, 52, 11, 19, 5) + S.rr(92, 52, 11, 19, 5); fill: Theme.accent }
        }
    }
}
