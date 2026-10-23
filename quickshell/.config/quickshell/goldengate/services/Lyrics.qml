pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Synced lyrics for what Spotify is playing, from LRCLIB (lrclib.net, free,
// no key): asked once per track, kept in memory. `index` is the line at the
// player's position, which is read four times a second only while something
// shows the lyrics (`wanted`).
Singleton {
    id: root

    readonly property var player: Media.player
    readonly property bool spotify: !!player && /spotify/i.test((player.identity || "") + " " + (player.dbusName || ""))
    readonly property string title: player ? player.trackTitle || "" : ""
    readonly property string artist: player ? player.trackArtist || "" : ""
    property var lines: []          // [{ t: seconds, text }]
    property real position: 0
    property bool wanted: false
    property string key: ""
    property var cache: ({})
    readonly property int index: {
        let i = -1;
        for (let j = 0; j < lines.length && lines[j].t <= position + 0.25; ++j) i = j;
        return i;
    }
    function line(i) { return i >= 0 && i < lines.length ? lines[i].text : ""; }

    onTitleChanged: later.restart()
    onArtistChanged: later.restart()
    onSpotifyChanged: later.restart()
    Timer { id: later; interval: 500; onTriggered: root.fetch() }

    function fetch() {
        if (!spotify || !title) { lines = []; key = ""; return; }
        const k = artist + "\n" + title;
        if (k === key) return;
        key = k;
        if (cache[k]) { lines = cache[k]; return; }
        lines = [];
        const len = player.length > 0 ? ["--data-urlencode", "duration=" + Math.round(player.length)] : [];
        req.want = k;
        req.command = ["curl", "-sfm", "8", "--get", "https://lrclib.net/api/get",
                       "--data-urlencode", "artist_name=" + artist, "--data-urlencode", "track_name=" + title].concat(len);
        req.running = true;
    }
    function parse(text, k) {
        let out = [];
        try {
            const j = JSON.parse(text);
            out = (j.syncedLyrics || "").split("\n").map(l => {
                const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
                return m ? { t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: m[3] } : null;
            }).filter(x => x && x.text.trim() !== "");
        } catch (e) { /* no lyrics for this one */ }
        cache[k] = out;
        if (k === key) lines = out;
    }
    Process {
        id: req
        property string want: ""
        stdout: StdioCollector { onStreamFinished: root.parse(this.text, req.want) }
    }

    Timer {
        running: root.wanted && !!root.player
        interval: 250
        repeat: true
        triggeredOnStart: true
        onTriggered: { root.player.positionChanged(); root.position = root.player.position; }
    }
}
