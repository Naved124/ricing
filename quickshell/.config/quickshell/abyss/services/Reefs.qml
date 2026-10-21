pragma Singleton

import QtQuick
import Quickshell

// Every screen's reef, by screen name, so the rest of the shell can touch
// the water: a card landing, the launcher opening, a click in the bar, the
// OSD changing (`disturb`, in that screen's px), a notification (the jelly
// nearest it flares). Only where the wallpaper shows is any of it seen.
Singleton {
    id: root

    property var reefs: ({})          // screen name → Reef
    property int count: 0

    function add(name, reef) {
        reefs[name] = reef;
        count = Object.keys(reefs).length;
    }
    function remove(name, reef) {
        if (reefs[name] === reef) delete reefs[name];
        count = Object.keys(reefs).length;
    }
    // (pass `count` from a binding so it looks again when a reef comes or goes)
    function on(screen, count) { return screen ? reefs[screen.name ?? screen] ?? null : null; }

    // strength 0..1: a keystroke is 0.15, a card 0.6, the launcher 1
    function disturb(screen, x, y, strength) {
        if (!Config.uiDisturbances) return;
        on(screen)?.disturb(x, y, strength ?? 0.5);
    }
    function notify(screen, x, y) {
        on(screen)?.notify(x, y);
    }
    function stats() {
        const out = {};
        for (const name of Object.keys(reefs)) out[name] = reefs[name].stats();
        return out;
    }
}
