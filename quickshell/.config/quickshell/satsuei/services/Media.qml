pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The player worth showing: the one playing, else the last one that played.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var last: null
    readonly property var player: players.find(p => p.isPlaying) ?? (players.includes(last) ? last : players[0] ?? null)
    readonly property bool playing: !!player && player.isPlaying

    onPlayerChanged: if (player?.isPlaying) last = player

    function fmt(secs) {
        if (!secs || secs < 0) return "0:00";
        const m = Math.floor(secs / 60), s = Math.floor(secs % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }
}
