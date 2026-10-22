pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.common

// Satsuei is the notification daemon while it runs (no swaync, no mako; `rice`
// hands the bus name over on a switch). Every notification is kept for the
// control centre's list until dismissed. New ones queue for the subtitles
// (subs/Subtitles.qml), one at a time, 5.2 s apiece; a critical one stays
// until it's clicked. Quiet keeps them out of the queue but in the list.
// Each arrival is announced (`arrived`): the edge mascot waves.
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    property var queue: []           // waiting for a subtitle, oldest first
    readonly property var current: queue[0] ?? null
    readonly property int lifetime: 5200
    property var times: ({})         // id → when it arrived (ms)
    signal arrived(var n)

    function timeOf(n) { return new Date(times[n?.id] ?? Date.now()); }
    function critical(n) { return n?.urgency === NotificationUrgency.Critical; }

    // the subtitle is done with it (its time ran out, or it was clicked)
    function done(n) {
        queue = queue.filter(p => p !== n);
    }
    function dismiss(n) {
        done(n);
        n.dismiss();
    }
    function clearAll() {
        queue = [];
        for (const n of all.slice()) n.dismiss();
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            const t = Object.assign({}, root.times);
            t[n.id] = Date.now();
            root.times = t;
            if (!Shell.dnd || root.critical(n))
                root.queue = [...root.queue, n];
            Shell.lastAlert = Date.now();
            root.arrived(n);
            n.closed.connect(() => root.done(n));
        }
    }
}
