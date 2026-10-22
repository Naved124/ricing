pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What Satsuei remembers: ~/.local/state/satsuei/settings.json. The pass's
// five effects and the compositing switch, the time of day, night light,
// Quiet, the mascot, which character plays each role, the wallpaper folder
// and its rotation. Written back whenever something changes; satsuei-wall
// reads wallDir from it too.
Singleton {
    id: root

    readonly property alias s: saved
    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                                   + "/satsuei/settings.json"

    // ── the pass ────────────────────────────────────────────────────────────
    function fx(name) { return !!saved[name]; }
    function setFx(name, on) { saved[name] = on; }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: saved
            // the compositing pass: on (the plate's light) or the raw plate
            property bool pass: true
            property bool bloom: true          // diffusion and bloom
            property bool rays: true           // shafts from the light source
            property bool motes: true          // dust in the light
            property bool grain: false         // film grain
            property bool grade: true          // the hour's colour
            property bool parallax: true
            property bool frost: true          // the plate blurred behind the windows, pass or no pass
            // the hour: the clock's, or held where the slider left it
            property bool follow: true
            property real hour: 7.2
            property bool nightLight: false
            // the brightness slider past the backlight (or on a screen with
            // none): the pass's exposure, 0.4–1.15
            property real expo: 1.0
            property bool quiet: false         // subtitles off; kept in the list
            property bool mascot: true
            // characters: the media card's dancer and the screen edge's mascot
            property string dancer: "hana"
            property string mascotChar: "hana"
            property bool shuffleDaily: false
            // the timesheet (desk/Stats.qml): shown, and where (0–1 across the
            // free area; it starts top right, under the bar)
            property bool statsShown: true
            property real statsX: 1
            property real statsY: 0
            property string shuffledOn: ""     // yyyy-mm-dd of the last daily pick
            // wallpapers
            property string wallDir: "~/Pictures/Wallpapers"
            property string rotate: "off"      // off, 15m, 30m, 1h, daily
            property string sort: "name"       // name, date, colour
            property string lastRotate: ""
        }
    }
}
