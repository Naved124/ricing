pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Shell-wide state: which surface is open (one at a time, as on the Mac),
// Focus (Do Not Disturb), Night Shift, caffeine, recording, and the system
// card on the desktop. What has to survive a restart is in shell.json.
Singleton {
    id: root

    // "" or one of: spotlight clipboard controlcenter notifications apps
    // mission expose power keys apple dockmenu island
    property string open: ""
    property string openScreen: ""
    function toggle(name) {
        if (open === name) { open = ""; return; }
        open = name;
        const m = Hyprland.focusedMonitor;
        openScreen = m ? m.name : "";
    }
    function closeAll() { open = ""; }
    function isOpen(name, screen) { return open === name && (!screen || openScreen === "" || openScreen === screen.name); }

    // the island's activity from `gg island test`, or a long command finishing
    property string islandTest: ""
    // text Spotlight opens with (shell search)
    property string searchText: ""
    property bool caffeine: false
    property bool recording: false
    property real recordingSince: 0
    property bool dnd: saved.dnd
    property bool nightLight: saved.nightLight
    readonly property bool statsShown: saved.statsShown
    readonly property point statsAt: Qt.point(saved.statsX, saved.statsY)
    readonly property bool weatherShown: saved.weatherShown
    readonly property point weatherAt: Qt.point(saved.weatherX, saved.weatherY)

    function setDnd(on) { saved.dnd = on; }
    function setNightLight(on) {
        saved.nightLight = on;
        run(["hyprctl", "hyprsunset", on ? "temperature" : "identity"].concat(on ? ["4300"] : []));
    }
    function setStatsShown(shown) { saved.statsShown = shown; }
    // screen recording through rice-rec: the panel closes first, so it isn't filmed
    function toggleRecording(kind) {
        closeAll();
        recKind = kind;
        recLater.restart();
    }
    property string recKind: "screen"
    Timer { id: recLater; interval: 350; onTriggered: root.run(["rice-rec", "toggle", root.recKind]) }
    function moveStats(x, y) { saved.statsX = x; saved.statsY = y; }
    function setWeatherShown(shown) { saved.weatherShown = shown; }
    function moveWeather(x, y) { saved.weatherX = x; saved.weatherY = y; }

    // a detached command (gg, rice-rec, hyprctl …)
    function run(cmd) { Quickshell.execDetached(cmd); }
    function gg(args) { run(["gg"].concat(args)); }

    onRecordingChanged: recordingSince = recording ? Date.now() : 0
    // a recording started before the shell was
    Process {
        running: true
        command: ["rice-rec", "status"]
        stdout: StdioCollector { onStreamFinished: root.recording = this.text.trim().startsWith("recording") }
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/goldengate/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()
        JsonAdapter {
            id: saved
            property bool dnd: false
            property bool nightLight: false
            property bool statsShown: false
            property real statsX: 0.04
            property real statsY: 0.62
            property bool weatherShown: false
            property real weatherX: 0.04
            property real weatherY: 0.3
        }
    }
}
