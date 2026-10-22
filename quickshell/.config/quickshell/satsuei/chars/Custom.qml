import QtQuick
import qs.common
import qs.services

// One of the user's own characters (a folder in ~/.config/satsuei/characters,
// see Characters): its clips played as they are, and moved like a built-in.
// It's a Rig, so it ticks like one and stands on the same 120 × 160 canvas.
//   · the clip: the mode's own, else idle, else the dance held still; the
//     dance plays only while the music does (frozen on its frame when it
//     pauses), at clamp(bpm / baseBpm, 0.6, 1.6) × (0.75 + 0.6 × level)
//   · placed by meta.json: fitted to the canvas by `scale`, feet on the
//     bottom less `trimBottom` (rows of the clip's own pixels), moved by
//     `offsetX`/`offsetY` (canvas units, the same on the card, the timesheet
//     and the edge), mirrored by `flip`
//   · the beat puppet: a GIF only loops, so the whole sprite bobs and sways
//     with the rig, squashes on the kick and hops on a drop, all scaled by
//     `puppet` (0.6) so a clip that already bounces isn't doubled up
//   · no wave clip: it springs and rocks; no sleep clip: it dims to 75%
//     under a floating "z z Z"
//   · drawn through SceneMatch (so it isn't a sticker on the plate): meta's
//     "recolor" rules ({ from, to: a token or a colour, tol, strength }) and
//     "protect" colours, the plate's grade ("ambient", 0.7), a rim toward
//     its light ("rim", 0.5), "outline" and the plate's grain; "match":
//     false draws it as it is
Rig {
    id: r

    readonly property var meta: cast?.meta ?? ({})
    readonly property var clips: cast?.clips ?? ({})
    readonly property real puppet: meta.puppet ?? 0.6
    profile: ({ bob: r.puppet, sway: r.puppet, tilt: 0, arms: 0, legs: 0, extra: 0 })

    // SceneMatch: on unless meta.json turns it off; the recolour rules with
    // their targets resolved (a theme token's name, or a colour as it is)
    readonly property bool matched: meta.match ?? true
    readonly property var tokens: ["accent", "accent2", "tint", "ink", "glass", "fg", "fgDim", "hair", "onAccent"]
    readonly property var rules: (meta.recolor ?? []).slice(0, 4).map(x => ({
        from: x.from, to: r.tokens.includes(x.to) ? Theme[x.to] : x.to,
        tol: x.tol ?? 0.1, strength: x.strength ?? 1 }))

    readonly property bool dancing: mode === "dance"
    readonly property string clipName: clips[mode] ? mode : mode !== "dance" && clips.idle ? "idle" : "dance"
    readonly property var clip: clips[clipName] ?? ({ path: "", sheet: false })
    readonly property bool held: clipName === "dance" && !dancing        // the dance standing in, still
    readonly property bool faking: clipName !== mode
    readonly property bool playing: running && !held && (clipName !== "dance" || Media.playing)
    readonly property real speed: clipName === "dance"
                                  ? Math.max(0.6, Math.min(1.6, Tempo.bpm / (meta.baseBpm || 100))) * (0.75 + 0.6 * Math.min(1, Beat.level))
                                  : 1

    // the clip's own size, and how it fits the canvas
    readonly property size natural: clip.sheet ? Qt.size(sheetSize.sourceSize.width / Math.max(1, meta.frames), sheetSize.sourceSize.height)
                                               : gif.sourceSize
    readonly property real fit: natural.width > 0 && natural.height > 0
                                ? Math.min(120 / natural.width, 160 / natural.height) * (meta.scale || 1) : 0

    // the made-up moves: the wave's spring and rock, the drop's hop
    readonly property real rock: faking && mode === "wave" ? Math.sin(t * 6) * 8 : 0
    readonly property real spring: faking && mode === "wave" ? Math.abs(Math.sin(t * 6)) * 6 : 0
    property real hop: dancing && Tempo.drop ? 10 * puppet : 0
    Behavior on hop { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    Part {
        id: all
        ox: 60; oy: 160
        dy: r.bob - r.hop - r.spring
        angle: r.sway + r.rock
        sy: r.dancing ? 1 - 0.07 * Tempo.kick * r.puppet : 1
        sx: 2 - sy

        // the character and a few px around it (for the outline), drawn
        // through SceneMatch unless meta.json says "match": false
        Item {
            id: matte
            readonly property int pad: 4
            x: body.x0 - pad
            y: body.y0 - pad
            width: body.width + 2 * pad
            height: body.height + 2 * pad
            opacity: r.faking && r.mode === "sleep" ? 0.75 : 1
            layer.enabled: r.matched && body.width > 0
            layer.textureSize: Qt.size(width * 2, height * 2)
            layer.smooth: true
            layer.effect: SceneMatch {
                rules: r.rules
                protect: r.meta.protect ?? []
                mulV: Theme.grade.mul
                liftV: Theme.grade.lift
                sat: Theme.grade.sat
                expo: Settings.s.expo
                ambient: (r.meta.ambient ?? 0.7) * (Settings.s.pass && Settings.s.grade ? 1 : 0)
                rim: (r.meta.rim ?? 0.5) * Theme.grade.rays * (Settings.s.pass && Settings.s.rays ? 1 : 0)
                rimV: Theme.grade.rayCol
                light: Qt.point(Theme.lightX - 0.5, Theme.lightY - 0.5)
                outline: r.meta.outline ? 1 : 0
                outlineCol: Theme.at(Theme.tint, 0.6)
                grain: Settings.s.pass && Settings.s.grain ? 1 : 0
            }

            Item {
                id: body
                readonly property real x0: 60 - width / 2 + (r.meta.offsetX ?? 0)
                readonly property real y0: 160 - height + (r.meta.trimBottom ?? 0) * r.fit + (r.meta.offsetY ?? 0)
                x: matte.pad
                y: matte.pad
                width: r.natural.width * r.fit
                height: r.natural.height * r.fit
                transform: Scale { origin.x: body.width / 2; xScale: r.meta.flip ? -1 : 1 }

                // until the first frame is in, the thumbnail
                Image {
                    anchors.fill: parent
                    visible: !!r.cast?.thumb && gif.status !== Image.Ready && !r.clip.sheet
                    source: r.cast?.thumb ?? ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                AnimatedImage {
                    id: gif
                    anchors.fill: parent
                    visible: !r.clip.sheet
                    source: r.clip.sheet ? "" : r.clip.path
                    playing: r.playing
                    speed: r.speed
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                }
                Image {
                    id: sheetSize
                    visible: false
                    source: r.clip.sheet ? r.clip.path : ""
                }
                AnimatedSprite {
                    anchors.fill: parent
                    visible: r.clip.sheet && sheetSize.status === Image.Ready
                    source: r.clip.sheet ? r.clip.path : ""
                    frameCount: Math.max(1, r.meta.frames ?? 1)
                    frameWidth: r.natural.width
                    frameHeight: r.natural.height
                    frameRate: Math.max(1, (r.meta.fps ?? 12) * r.speed)
                    running: r.playing && visible
                    interpolate: false
                    smooth: true
                }
            }
        }
    }

    // asleep with no clip for it
    Repeater {
        model: r.faking && r.mode === "sleep" ? 3 : 0
        delegate: Label {
            required property int index
            readonly property real f: (r.t * 0.5 + index / 3) % 1
            x: 72 + index * 9 + Math.sin(f * 6) * 3
            y: matte.y + 10 - f * 30
            opacity: Math.sin(f * Math.PI)
            size: 9 + index * 3
            weight: Style.weightStrong
            color: Theme.fg
            text: index === 2 ? "Z" : "z"
        }
    }
}
