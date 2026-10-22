pragma Singleton

import QtQuick
import Quickshell

// Every screen's plate, by screen name, for the stats.
Singleton {
    id: root
    property var plates: ({})
    function add(name, p) { plates[name] = p; }
    function remove(name, p) { if (plates[name] === p) delete plates[name]; }
    function stats() {
        const out = {};
        for (const name of Object.keys(plates)) out[name] = plates[name].stats();
        return out;
    }
}
