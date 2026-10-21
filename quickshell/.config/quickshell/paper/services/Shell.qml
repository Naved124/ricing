pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Shell-wide state: which surfaces are open, Do Not Disturb, night light,
// and whether the paper grain is on. DND and night light survive restarts
// (and rice switches) through a small JSON file; the grain is `rice grain`'s.
Singleton {
    id: root

    property bool launcherOpen: false
    property string launcherMode: ""      // "" apps, "!" clipboard
    property string launcherText: ""      // prefilled query (ipc: shell search)
    property bool centerOpen: false
    property bool powerOpen: false
    property bool keysOpen: false
    property bool calendarPeek: false     // the clock was clicked: show the month in the centre
    property bool caffeine: false
    property bool recording: false
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

    // the grain's on/off lives in rice's state file; read it, flip it through rice
    readonly property string grainMarker: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice/grain-off"
    property bool grain: true

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

    function toggleCenter() {
        const open = !centerOpen;
        closeAll();
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

    function closeAll() {
        launcherOpen = false;
        centerOpen = false;
        powerOpen = false;
        keysOpen = false;
        calendarPeek = false;
    }

    function setDnd(on) {
        saved.dnd = on;
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

    function setGrain(on) {
        grain = on;
        grainSet.command = ["rice", "grain", on ? "on" : "off"];
        grainSet.running = true;
    }

    Process {
        id: grainSet
        onExited: grainCheck.running = true
    }
    // the marker can change behind our back (Super+Shift+G), so look again
    // whenever the control centre opens
    Process {
        id: grainCheck
        running: true
        command: ["sh", "-c", 'test -e "$1" && echo off || echo on', "sh", root.grainMarker]
        stdout: StdioCollector {
            onStreamFinished: root.grain = text.trim() !== "off"
        }
    }
    onCenterOpenChanged: if (centerOpen) grainCheck.running = true

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
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: saved
            property bool dnd: false
            property bool nightLight: false
            property bool statsShown: true
            property real statsX: 0.03
            property real statsY: 0.09
        }
    }
}
