pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Paper is the notification daemon (no swaync). New notifications queue
// for the island (bar/Island.qml), which unfolds into a sticky note for
// each in turn, 4 s apiece; everything is kept for the island's history
// until dismissed. Do Not Disturb keeps them out of the queue (the island's
// count still goes up); critical ones still come through.
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    property var queue: []           // waiting for the island, oldest first
    readonly property var current: queue[0] ?? null
    readonly property int lifetime: 4000

    // the island is done with it (its time ran out, or the app closed it)
    function done(n) {
        queue = queue.filter(p => p !== n);
    }

    function dismiss(n) {
        done(n);
        n.dismiss();
    }

    // the history was opened: everything waiting is in there now
    function seen() {
        queue = [];
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
        inlineReplySupported: false

        onNotification: n => {
            n.tracked = true;
            if (!Shell.dnd || n.urgency === NotificationUrgency.Critical)
                root.queue = [...root.queue, n];
            n.closed.connect(() => root.done(n));
        }
    }
}
