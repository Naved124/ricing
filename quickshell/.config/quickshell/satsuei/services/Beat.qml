pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The music's shape, from one cava for the whole shell: `levels` (30 bands,
// 0..1, bass on the left) for the media card's bars and the bar's equaliser,
// and `level`, the beat: the low bands' loudness with a fast rise and a slow
// fall, for what moves with the music (the dancer). Runs only while something
// plays, in raw ascii mode with a config of Satsuei's own
// (~/.cache/satsuei/cava.conf), so it starts and stops with this shell and
// touches no other cava; quietly flat when cava isn't installed.
Singleton {
    id: root

    readonly property int bars: 30
    property var levels: []
    property real level: 0
    readonly property bool live: levels.length > 0

    function take(line) {
        const v = line.split(";").filter(s => s !== "").map(s => parseInt(s) / 100);
        if (v.length !== bars || v.some(isNaN)) return;
        root.levels = v;
        const low = v.slice(0, 6).reduce((a, b) => a + b, 0) / 6;
        // rise at once, fall over about half a second (30 frames a second)
        root.level = low > root.level ? low : root.level * 0.88 + low * 0.12;
    }

    Process {
        id: cava
        running: Media.playing
        command: ["sh", "-c", `
            command -v cava >/dev/null || exit 0
            dir="\${XDG_CACHE_HOME:-$HOME/.cache}/satsuei"; mkdir -p "$dir"
            cat > "$dir/cava.conf" <<CONF
[general]
bars = ${root.bars}
framerate = 30
[input]
method = pipewire
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
[smoothing]
noise_reduction = 70
CONF
            exec cava -p "$dir/cava.conf"`]
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
        onRunningChanged: if (!running) { root.levels = []; root.level = 0; }
    }
}
