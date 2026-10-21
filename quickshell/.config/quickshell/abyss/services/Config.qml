pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ~/.config/rice/abyss.toml, re-read whenever it changes. Every key is
// optional; the defaults are below (and in the file the installer ships,
// switcher/.local/share/rice/abyss.toml, with what each one does).
Singleton {
    id: root

    readonly property var defaults: ({
        fps: 30,                  // the reef's frame rate: 30 or 60
        scale: 0.55,              // what's drawn of it, against the screen's size
        plankton: 620,            // at most (fewer on a small screen)
        fish: 24,
        jellies: 5,
        interactive: true,        // the reef feels the pointer where it's uncovered
        music_react: true,        // plankton, coral tips and rays pulse to the music
        ui_disturbances: true,    // the shell touches the water (cards, launcher, bar, OSD)
        reduce_on_battery: true   // 15 fps, half the plankton and no bloom under 30%
    })
    property var values: defaults

    readonly property int fps: Math.max(5, Math.min(60, Math.round(get("fps"))))
    readonly property real scale: Math.max(0.25, Math.min(1, get("scale")))
    readonly property int plankton: Math.max(0, Math.round(get("plankton")))
    readonly property int fish: Math.max(0, Math.min(60, Math.round(get("fish"))))
    readonly property int jellies: Math.max(0, Math.min(9, Math.round(get("jellies"))))
    readonly property bool interactive: !!get("interactive")
    readonly property bool musicReact: !!get("music_react")
    readonly property bool uiDisturbances: !!get("ui_disturbances")
    readonly property bool reduceOnBattery: !!get("reduce_on_battery")

    function get(key) {
        const v = values[key];
        return v === undefined || typeof v !== typeof defaults[key] ? defaults[key] : v;
    }

    // `key = value` lines: numbers, true/false and "strings"; # comments
    function parse(text) {
        const out = Object.assign({}, defaults);
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.replace(/#.*$/, "").trim();
            const m = line.match(/^([A-Za-z_][\w]*)\s*=\s*(.+)$/);
            if (!m) continue;
            const v = m[2].trim();
            if (v === "true" || v === "false") out[m[1]] = v === "true";
            else if (/^-?\d+(\.\d+)?$/.test(v)) out[m[1]] = Number(v);
            else if (/^".*"$/.test(v)) out[m[1]] = v.slice(1, -1);
        }
        return out;
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/rice/abyss.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.values = root.parse(text())
        onLoadFailed: root.values = root.defaults
    }
}
