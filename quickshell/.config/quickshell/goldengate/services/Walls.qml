pragma Singleton

import QtQuick
import Quickshell

// The wallpaper, for everything that draws or samples it: the desktop, the
// lock screen, the shell's own Liquid shader, the screen saver. Paths come
// from Settings (gg wall set writes them); "~" is the home folder.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    function url(path) {
        if (!path)
            return "";
        const p = String(path).replace(/^~(?=\/|$)/, home);
        return p.startsWith("/") ? "file://" + p : p;
    }

    readonly property string day: url(Settings.wallpaper.current)
    readonly property string night: url(Settings.wallpaper.currentDark)
    // the picture on screen in a mode (a pair's half at that end)
    function at(dark) { return (dark && night) ? night : day; }
    function lockAt(dark) { return Settings.wallpaper.lock ? url(Settings.wallpaper.lock) : at(dark); }

    readonly property int fillMode: ({
        fill: Image.PreserveAspectCrop, fit: Image.PreserveAspectFit, stretch: Image.Stretch,
        center: Image.Pad, tile: Image.Tile
    })[Settings.wallpaper.fill] ?? Image.PreserveAspectCrop
}
