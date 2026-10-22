pragma Singleton

import QtQuick
import Quickshell

// The music's tempo and its hits, for the characters, from Beat's bands:
//   bpm    a guess from the kicks (the low bands jumping over their own
//          running average), the median gap of the last twelve, folded into
//          70–160; 96 until there are enough
//   kick   the low bands now (0–1), for a squash on the kick
//   drop   true for 600 ms when the level jumps by a third within a second
// It only listens while Beat has bands (something plays and cava runs).
Singleton {
    id: root

    property real bpm: 96
    property real kick: 0
    property bool drop: false

    property real avg: 0
    property real slow: 0
    property double lastHit: 0
    property var gaps: []

    Connections {
        target: Beat
        function onLevelsChanged() { root.take(Beat.levels); }
    }

    function take(v) {
        if (v.length < 4) return;
        const low = (v[0] + v[1] + v[2] + v[3]) / 4;
        kick = low;
        const now = Date.now();
        if (low > avg * 1.35 + 0.05 && now - lastHit > 250) {
            const gap = now - lastHit;
            lastHit = now;
            if (gap >= 300 && gap <= 1600) {
                const g = gaps.concat([gap]).slice(-12);
                gaps = g;
                if (g.length >= 6) {
                    const m = g.slice().sort((a, b) => a - b)[g.length >> 1];
                    let b = 60000 / m;
                    while (b < 70) b *= 2;
                    while (b > 160) b /= 2;
                    bpm = bpm * 0.7 + b * 0.3;
                }
            }
        }
        avg = avg * 0.9 + low * 0.1;
        // a drop: the loudness well over where it's been for the last second
        if (Beat.level - slow > 0.33 && !drop) {
            drop = true;
            dropEnd.restart();
        }
        slow = slow * 0.97 + Beat.level * 0.03;
    }
    Timer { id: dropEnd; interval: 600; onTriggered: root.drop = false }
}
