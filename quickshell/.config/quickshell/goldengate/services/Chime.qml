pragma Singleton

import QtQuick
import Quickshell
import qs.services

// The notification sound: one of the shell's own (sounds/, made by
// tools/gg-sounds), the sound theme's message sound ("system"), or "none",
// at Settings.sound.notificationVolume, through PipeWire's pw-play. Do Not
// Disturb keeps it quiet, as it keeps the banner away.
Singleton {
    id: root

    readonly property var choices: ["glass", "crystal", "bloom", "pop", "system", "none"]
    readonly property string dir: Qt.resolvedUrl("../sounds/").toString().replace(/^file:\/\//, "")

    function file(name) {
        return name === "system" ? "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga" : dir + name + ".wav";
    }
    function play(name) {
        const n = name || Settings.sound.notification;
        if (!n || n === "none") return;
        Quickshell.execDetached(["pw-play", "--volume", String(Settings.sound.notificationVolume), file(n)]);
    }

    Connections {
        target: Notifs
        function onArrived(n) { root.play(); }
    }
}
