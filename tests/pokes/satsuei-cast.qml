import QtQuick
import Quickshell
import qs.chars
import qs.common
import qs.services

// tests/test_satsuei.py: with the fixture character in the folder, cast it as
// the dancer, open the control centre (the strip), send it through every
// mode on the timesheet, then cast a built-in as the mascot.
Item {
    property int step: 0
    readonly property var steps: [
        () => console.warn("POKE:" + JSON.stringify({ tag: "found", ids: Characters.all.map(c => c.id),
                                                       test: Characters.byId("test") })),
        () => { Characters.set("dancer", "test"); Shell.toggleCenter(); },
        () => Settings.s.statsShown = true,
        () => { Sys.cpu = 0.95; },
        () => Characters.set("mascot", "bit"),
        () => console.warn("POKE:" + JSON.stringify({ tag: "cast", dancer: Characters.dancer.id,
                                                       mascot: Characters.mascot.id, open: Shell.centerOpen })),
    ]
    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (parent.step >= parent.steps.length) { running = false; return; }
            parent.steps[parent.step]();
            parent.step++;
        }
    }
}
