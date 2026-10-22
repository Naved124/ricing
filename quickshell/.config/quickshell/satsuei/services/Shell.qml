pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Shell-wide state: which surfaces are open, recording, the lock. What's
// remembered (Quiet, night light, the pass, the characters) is in
// common/Settings.qml.
Singleton {
    id: root

    property bool launcherOpen: false
    property string launcherMode: ""      // "", "=", "/", ":", ">", "?", "!"
    property string launcherText: ""      // prefilled query (ipc: shell search)
    property bool centerOpen: false       // the control centre, the right drawer
    property string centerFocus: ""       // what to scroll to when it opens ("" for the top)
    property bool studioOpen: false       // the Satsuei panel, the left drawer
    property bool powerOpen: false
    property bool keysOpen: false
    property bool wallsOpen: false        // the wallpaper selector (Super+Ctrl+W)
    property bool castOpen: false         // the Cast picker (Super+Alt+C)
    property string castRole: "dancer"    // the role the picker assigns: dancer or mascot
    // the Satsuei panel's tools over the plate: picking the light source with a
    // crosshair, and holding to see the raw plate
    property bool pickingLight: false
    property bool comparing: false
    // caffeine: hold off dimming, locking and sleep (bar/Bar.qml inhibits idle).
    // Deliberately forgotten on restart, so it can't drain a battery overnight.
    property bool caffeine: false
    property bool recording: false
    // the session lock is up: the plates' passes stop (the lock grades its own)
    property bool locked: false
    property real recordingSince: 0       // ms since the epoch, 0 when idle
    property int recordingSecs: 0
    readonly property string recordingTime: `${Math.floor(recordingSecs / 60)}:${String(recordingSecs % 60).padStart(2, "0")}`
    // Quiet: notifications are kept in the list but no subtitle shows
    readonly property bool dnd: Settings.s.quiet
    readonly property bool nightLight: Settings.s.nightLight
    readonly property int nightTemp: 4300  // kelvin, through hyprsunset's IPC
    // a notification arrived (subtitles, the mascot's wave)
    property double lastAlert: 0

    // the timesheet on the desktop (desk/Stats.qml), kept in Settings
    readonly property bool statsShown: Settings.s.statsShown
    readonly property point statsAt: Qt.point(Settings.s.statsX, Settings.s.statsY)
    function setStatsShown(on) { Settings.s.statsShown = on; }
    function setStatsAt(x, y) {
        Settings.s.statsX = Math.max(0, Math.min(1, x));
        Settings.s.statsY = Math.max(0, Math.min(1, y));
    }

    // a small pill (osd/Toast.qml shows it)
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

    function toggleStudio() {
        const open = !studioOpen;
        closeAll();
        studioOpen = open;
    }
    function toggleWalls() {
        const open = !wallsOpen;
        closeAll();
        wallsOpen = open;
    }
    function toggleCast(role) {
        const open = !castOpen || (role !== undefined && role !== castRole);
        closeAll();
        if (role) castRole = role;
        castOpen = open;
    }

    function closeAll() {
        launcherOpen = false;
        centerOpen = false;
        studioOpen = false;
        powerOpen = false;
        keysOpen = false;
        wallsOpen = false;
        castOpen = false;
        pickingLight = false;
        comparing = false;
    }

    function setDnd(on) {
        Settings.s.quiet = on;
    }

    function setNightLight(on) {
        Settings.s.nightLight = on;
        applyNightLight();
    }

    // the grade tints the plate; hyprsunset warms the windows too
    function applyNightLight() {
        Quickshell.execDetached(Settings.s.nightLight
            ? ["hyprctl", "hyprsunset", "temperature", String(nightTemp)]
            : ["hyprctl", "hyprsunset", "identity"]);
    }

    // hyprsunset starts alongside the shell; give it a moment, then restore
    // ours, off included, so a warm screen from another rice doesn't linger
    Timer {
        interval: 3000
        running: true
        onTriggered: root.applyNightLight()
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
}
