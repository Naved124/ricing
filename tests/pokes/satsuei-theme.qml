import QtQuick
import Quickshell
import qs.common

// tests/test_satsuei.py: what Theme reads, before and after the test rewrites
// theme.json under the stand-in HOME (at 1.6 s), and mid-fade.
Item {
    function report(tag) {
        console.warn("POKE:" + JSON.stringify({ tag: tag, ready: Theme.ready, seed: Theme.isSeed,
            accent: Theme.accent.toString(), tint: Theme.tint.toString(), plate: Theme.plate,
            lightX: Theme.lightX, phase: Theme.grade.phase, rays: Theme.grade.rays,
            mode: Theme.mode.dark }));
    }
    Timer { interval: 900; running: true; onTriggered: parent.report("first") }
    Timer { interval: 2150; running: true; onTriggered: parent.report("fading") }
    Timer { interval: 3600; running: true; onTriggered: parent.report("after") }
}
