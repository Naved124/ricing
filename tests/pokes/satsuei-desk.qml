import QtQuick
import Quickshell
import Quickshell.Io
import qs.chars
import qs.common
import qs.services
import qs.walls

// tests/test_satsuei.py: the mascot, the wallpaper selector and the Satsuei
// panel. A notification wakes the mascot; the selector opens on the
// fixture folder, moves (the preview) and goes back (Esc); the panel opens,
// a pass switch flips and the light picker starts and stops.
Item {
    property int step: 0
    readonly property var steps: [
        () => Quickshell.execDetached(["notify-send", "hi"]),
        () => { Library.items = [
                    { path: "/w/a.jpg", rel: "a.jpg", mtime: 2, thumb: "", accent: "#88aaff", accent2: "#ffaa88",
                      tint: "#101420", onAccent: "#101420", fg: "#eef0f8", fgDim: "#a0a8c0", ink: "#05070c",
                      hair: "#202840", swatches: ["#112233", "#445566", "#778899", "#aabbcc", "#ddeeff", "#334455"],
                      lightX: 0.6, lightY: 0.2, width: 1920, height: 1080, animated: false },
                    { path: "/w/b/c.png", rel: "b/c.png", mtime: 1, pending: true }];
                IpcRegistry.call("satsuei", "wallpaper", "open"); },
        () => console.warn("POKE:" + JSON.stringify({ tag: "walls", open: Shell.wallsOpen, shown: Library.shown.length,
                                                       folders: Library.folders })),
        () => { Library.folder = "b"; Settings.s.sort = "colour"; },
        () => { Library.folder = ""; Library.query = "a"; },
        () => { Library.query = ""; Shell.wallsOpen = false; },
        () => IpcRegistry.call("shell", "studio"),
        () => { Settings.setFx("grain", true); Settings.s.follow = false; Settings.s.hour = 18.2; },
        () => { Shell.studioOpen = false; Shell.pickingLight = true; },
        () => { Shell.pickingLight = false; Settings.s.follow = true; },
        () => console.warn("POKE:" + JSON.stringify({ tag: "studio", open: Shell.studioOpen, grain: Settings.fx("grain"),
                                                       previewing: Theme.previewing !== null })),
    ]
    Timer {
        interval: 450
        repeat: true
        running: true
        onTriggered: {
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step]();
            parent.step++;
        }
    }
}
