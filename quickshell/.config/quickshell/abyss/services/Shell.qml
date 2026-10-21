pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Shell-wide state: which surfaces are open, Do Not Disturb, recording, and
// the reef's switches (the pointer reaching it, the stats overlay). DND and
// the reef's pointer survive restarts (and rice switches) through a small
// JSON file.
Singleton {
    id: root

    property bool launcherOpen: false
    property string launcherMode: ""      // "", "=", "/", ":", ">", "?", "!"
    property string launcherText: ""      // prefilled query (ipc: shell search)
    property bool centerOpen: false
    property string centerFocus: ""       // "" or "calendar"
    property bool powerOpen: false
    property bool keysOpen: false
    // the island's drop-down (what's playing and the notification history),
    // open under the island on one screen (its name)
    property bool islandOpen: false
    property string islandScreen: ""
    // caffeine: hold off dimming, locking and sleep (bar/Bar.qml inhibits idle).
    // Deliberately forgotten on restart, so it can't drain a battery overnight.
    property bool caffeine: false
    property bool recording: false
    // the session lock is up: the wallpaper reefs stop (the lock has its own)
    property bool locked: false
    // the reef feels the pointer (Super+Ctrl+R), and its stats overlay
    // (Super+Ctrl+Shift+R)
    readonly property bool reefInteractive: saved.reefInteractive
    property bool reefStats: false
    property real recordingSince: 0       // ms since the epoch, 0 when idle
    property int recordingSecs: 0
    readonly property string recordingTime: `${Math.floor(recordingSecs / 60)}:${String(recordingSecs % 60).padStart(2, "0")}`
    property bool dnd: saved.dnd
    property bool nightLight: saved.nightLight
    // the system card on the desk: shown or not, and where it was left
    // (fractions of the screen, so it lands in the same place at any size)
    readonly property bool statsShown: saved.statsShown
    readonly property point statsAt: Qt.point(saved.statsX, saved.statsY)
    readonly property int nightTemp: 4300  // kelvin, through hyprsunset's IPC

    // where the launcher blooms from (the orb), in screen coordinates
    property point orbCenter: Qt.point(0, 0)
    property var orbScreen: null

    // a small pill under the bar (osd/Toast.qml shows it)
    signal toast(string icon, string text)

    function toggleLauncher(mode) {
        if (launcherOpen && (mode === undefined || mode === launcherMode)) {
            launcherOpen = false;
            return;
        }
        closeAll();
        launcherMode = mode ?? "";
        launcherText = "";
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

    function toggleKeys() {
        const open = !keysOpen;
        closeAll();
        keysOpen = open;
    }

    function toggleIsland(name) {
        const open = !(islandOpen && islandScreen === name);
        closeAll();
        islandScreen = name;
        islandOpen = open;
    }

    function closeAll() {
        islandOpen = false;
        launcherOpen = false;
        centerOpen = false;
        powerOpen = false;
        keysOpen = false;
    }

    function setDnd(on) {
        saved.dnd = on;
    }

    function setReefInteractive(on) {
        saved.reefInteractive = on;
        toast(on ? "touch" : "touch-off", on ? "The reef feels the pointer" : "The reef ignores the pointer");
    }

    function setStatsShown(on) {
        saved.statsShown = on;
    }
    function setStatsAt(x, y) {
        saved.statsX = Math.max(0, Math.min(1, x));
        saved.statsY = Math.max(0, Math.min(1, y));
    }

    function setNightLight(on) {
        saved.nightLight = on;
        applyNightLight();
    }

    function applyNightLight() {
        Quickshell.execDetached(saved.nightLight
            ? ["hyprctl", "hyprsunset", "temperature", String(nightTemp)]
            : ["hyprctl", "hyprsunset", "identity"]);
    }

    // hyprsunset starts alongside the shell; give it a moment, then restore
    Timer {
        interval: 3000
        running: true
        onTriggered: if (root.nightLight) root.applyNightLight()
    }

    // ── screen recording (rice-rec does the work; it tells us through ipc) ──
    function toggleRecording(mode) {
        Quickshell.execDetached(["rice-rec", "toggle", mode ?? "screen"]);
    }
    onRecordingChanged: {
        recordingSince = recording ? (recordingSince || Date.now()) : 0;
        recordingSecs = 0;
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        triggeredOnStart: true
        onTriggered: root.recordingSecs = Math.max(0, Math.floor((Date.now() - root.recordingSince) / 1000))
    }
    // a restarted shell picks up a recording that's still going
    Process {
        running: true
        command: ["rice-rec", "status"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split(" ");
                if (f[0] !== "recording") return;
                root.recordingSince = Number(f[1]) * 1000;
                root.recording = true;
            }
        }
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
            property bool nightLight: false
            property bool statsShown: true
            property real statsX: 0.03
            property real statsY: 0.09
            property bool reefInteractive: true
        }
    }
}
