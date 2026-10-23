pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Everything Golden Gate remembers: ~/.config/goldengate/settings.json, one
// group per System Settings pane. The file is watched, so `gg` (which edits
// it with jq) and the Settings app change the shell live; whatever the shell
// changes is written straight back. Light and dark aren't here: they're the
// rice mode (~/.local/state/rice/mode), which every rice shares.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
                                  + "/goldengate"
    readonly property string path: dir + "/settings.json"

    readonly property alias appearance: saved.appearance
    readonly property alias glass: saved.glass
    readonly property alias accessibility: saved.accessibility
    readonly property alias wallpaper: saved.wallpaper
    readonly property alias location: saved.location
    readonly property alias menubar: saved.menubar
    readonly property alias island: saved.island
    readonly property alias dock: saved.dock
    readonly property alias desktop: saved.desktop
    readonly property alias windows: saved.windows
    readonly property alias sound: saved.sound
    readonly property alias user: saved.user

    // reduce motion: springs become 150 ms fades, and no Genie
    readonly property bool reduceMotion: saved.accessibility.reduceMotion
    // reduce transparency is Solid glass wherever glass is drawn
    readonly property string glassMode: saved.accessibility.reduceTransparency ? "solid" : saved.glass.mode

    // set("glass.clarity", 0.4): for the Settings app and the Control Center,
    // where a pane only knows the setting's name
    function set(key, value) {
        const parts = String(key).split(".");
        let o = saved;
        for (let i = 0; i < parts.length - 1; ++i)
            o = o[parts[i]];
        o[parts[parts.length - 1]] = value;
    }
    function get(key) {
        let o = saved;
        for (const p of String(key).split("."))
            o = o?.[p];
        return o;
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // the first time, write the defaults, once the failed load has ended
        // (writing from inside its handler drops it mid-flight)
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) Qt.callLater(writeAdapter); }

        JsonAdapter {
            id: saved

            property JsonObject appearance: JsonObject {
                // blue purple pink red orange yellow green graphite multicolor,
                // or wallpaper (gg accent wallpaper: the picture's vivid colour,
                // snapped to the nearest Apple hue, kept in accentWall)
                property string accent: "blue"
                property string accentBase: "blue"
                property var accentWall: ({ light: "", dark: "" })   // set by gg accent wallpaper
                property string highlight: "accent"        // the text selection's colour
                property string iconStyle: "default"       // default dark clear tinted
                property string widgetStyle: "default"
                property string sidebarIconSize: "medium"  // small medium large
                property bool menuBarBackground: false
                property string scrollBars: "auto"          // auto scrolling always
                property string clockFormat: "EEE d MMM  h:mm AP"
            }

            property JsonObject glass: JsonObject {
                property string mode: "liquid"      // liquid frosted solid
                property real clarity: 0.35         // 0 Ultraclear … 1 Tinted
                property bool accurate: false       // shell shader: live screen, not the wallpaper
                property string backend: "auto"     // auto plugin hyprliquid shader
            }

            property JsonObject accessibility: JsonObject {
                property bool reduceTransparency: false
                property bool reduceMotion: false
                property bool increaseContrast: false
                property int cursorSize: 24
            }

            property JsonObject wallpaper: JsonObject {
                property string dir: "~/Pictures/Wallpapers"   // shared with Satsuei
                property string current: ""        // the picture (by day, when it has a pair)
                property string currentDark: ""    // its night twin (name-dark.* beside name-light.*), or ""
                property string fill: "fill"       // fill fit stretch center tile
                property string rotate: "off"      // off 15m 1h daily
                property string lock: ""           // the lock screen's own, or "" for the desktop's
            }

            // auto light/dark: where the sun is (rice-sun reads ~/.config/rice/mode.toml)
            property JsonObject location: JsonObject {
                property string city: ""
                property real lat: 0
                property real lon: 0
            }

            property JsonObject menubar: JsonObject {
                property var order: ["tray", "keyboard", "focus", "nowplaying", "bluetooth", "wifi", "battery", "spotlight", "controlcenter", "clock"]
                property bool batteryPercent: false
                property bool nowPlaying: true
                property bool autohide: false
            }

            property JsonObject island: JsonObject {
                property string show: "always"    // always activities off
                property string style: "black"    // black glass
                property string osd: "island"     // island classic
            }

            property JsonObject dock: JsonObject {
                property int size: 56
                property bool magnify: true
                property int magnifySize: 96
                property string position: "bottom"   // bottom left right
                property bool autohide: false
                property int autohideDelay: 0
                property bool recents: true
                property bool minimizeIntoApp: false
                property string minimizeEffect: "genie"   // genie scale
                property var pinned: ["org.gnome.Nautilus", "firefox", "kitty", "org.gnome.Calendar", "spotify", "goldengate-settings"]
            }

            property JsonObject desktop: JsonObject {
                property bool widgets: true
                property bool monochrome: true          // widgets fade when windows cover them
                property bool clickRevealsDesktop: true
                property var hotCorners: ({ tl: "none", tr: "notifications", bl: "missioncontrol", br: "desktop" })
            }

            property JsonObject windows: JsonObject {
                property string layout: "floating"   // floating tiled
            }

            property JsonObject sound: JsonObject {
                property bool uiSounds: true
                property bool volumeFeedback: true
            }

            property JsonObject user: JsonObject {
                property string name: ""
                property string avatar: ""
            }
        }
    }
}
