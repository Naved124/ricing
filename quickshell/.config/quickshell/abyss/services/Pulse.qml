pragma Singleton

import QtQuick
import Quickshell

// The beat, for the reef: an onset in the bass of the shell's one cava
// (Beat.levels) kicks the plankton, the coral tips and the rays; a short
// refractory keeps a held note from kicking again. With music playing and
// no cava, the reef breathes at 0.5 Hz instead of faking a beat.
Singleton {
    id: root

    signal kicked()
    readonly property bool breathing: Media.playing && !Beat.live
    property real average: 0         // the bass's recent level
    property double lastKick: 0

    Connections {
        target: Beat
        function onLevelsChanged() {
            const v = Beat.levels;
            if (v.length < 6) return;
            const low = (v[0] + v[1] + v[2] + v[3]) / 4;
            const now = Date.now();
            // a jump well above the running level, at most every 180 ms
            if (low > root.average * 1.35 + 0.08 && now - root.lastKick > 180) {
                root.lastKick = now;
                root.kicked();
            }
            root.average = root.average * 0.9 + low * 0.1;
        }
    }
}
