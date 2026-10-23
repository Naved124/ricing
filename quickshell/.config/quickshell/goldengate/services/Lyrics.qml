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
    Component.onCompleted: later.restart()

    function fetch() {
        if (!spotify || !title) { lines = []; key = ""; return; }
        lookup(artist, title, player.length > 0 ? Math.round(player.length) : 0);
    }
    // the exact match first (title, artist, length), else LRCLIB's search
    // with "(feat. …)" and " - Remastered" taken off the title
    function lookup(a, t, secs) {
        const k = a + "\n" + t;
        if (k === key && (lines.length || req.running)) return;
        key = k;
        if (cache[k]) { lines = cache[k]; return; }
        lines = [];
        req.running = false;   // a lookup still going is for another song
        req.want = k;
        req.command = ["sh", "-c", `
            r=$(curl -sm12 --get https://lrclib.net/api/get --data-urlencode "artist_name=$1" --data-urlencode "track_name=$2" \${3:+--data-urlencode "duration=$3"})
            case "$r" in *'"syncedLyrics":"'*) printf '%s' "$r"; exit ;; esac
            t=$(printf '%s' "$2" | sed -E 's/ *[([](feat|with|ft)\.?[^])]*[])]//I; s/ - .*(remaster|version|edit|mix).*$//I')
            curl -sm12 --get https://lrclib.net/api/search --data-urlencode "artist_name=\${1%%,*}" --data-urlencode "track_name=$t" |
                jq -c '[.[] | select(.syncedLyrics)][0] // {}'`, "sh", a, t, secs > 0 ? String(secs) : ""];
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
            cache[k] = out;   // only a real answer is kept: a failed request tries again next time
        } catch (e) { /* offline or an error page: nothing kept */ }
        console.info("lyrics:", k.replace("\n", " — "), out.length, "lines");
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
