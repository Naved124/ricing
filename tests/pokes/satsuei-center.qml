import QtQuick
import Quickshell
import qs.common
import qs.services

// tests/test_satsuei.py: open the control centre; toggle Quiet and back.
Item {
    Timer {
        interval: 200; running: true
        onTriggered: {
            Shell.toggleCenter();
            Shell.setDnd(true);
            Shell.setDnd(false);
            console.warn("POKE:" + JSON.stringify({ tag: "open", open: Shell.centerOpen, notes: Notifs.all.length,
                                                     bars: Beat.bars, quiet: Shell.dnd }));
        }
    }
}
