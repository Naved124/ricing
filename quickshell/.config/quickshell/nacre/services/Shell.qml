pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Shell-wide state: which surfaces are open, Do Not Disturb, recording.
// DND survives restarts (and rice switches) through a small JSON file.
Singleton {
    id: root

    property bool launcherOpen: false
    property string launcherMode: ""      // "", "=", "/", ":", ">", "?", "!"
    property bool centerOpen: false
    property string centerFocus: ""       // "", "calendar", "media"
    property bool powerOpen: false
    property bool recording: false
    property bool dnd: saved.dnd

    // where the launcher blooms from (the orb), in screen coordinates
    property point orbCenter: Qt.point(0, 0)
    property var orbScreen: null

    function toggleLauncher(mode) {
        if (launcherOpen && (mode === undefined || mode === launcherMode)) {
            launcherOpen = false;
            return;
        }
        closeAll();
        launcherMode = mode ?? "";
        launcherOpen = true;
    }

    function toggleCenter(focus) {
        const open = !centerOpen;
        closeAll();
        centerFocus = focus ?? "";
        centerOpen = open;
    }

    function togglePower() {
        const open = !powerOpen;
        closeAll();
        powerOpen = open;
    }

    function closeAll() {
        launcherOpen = false;
        centerOpen = false;
        powerOpen = false;
    }

    function setDnd(on) {
        saved.dnd = on;
    }

    FileView {
        path: Quickshell.statePath("shell.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // first run: write the defaults
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: saved
            property bool dnd: false
        }
    }
}
