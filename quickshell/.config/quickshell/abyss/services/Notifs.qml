pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Abyss is the notification daemon (no swaync, no mako).
// Every notification is kept for the island's history until dismissed. New
// ones queue for the island (bar/Island.qml), which grows into a card for
// each in turn, 4 s apiece. Do Not Disturb keeps them out of the queue (the
// island's count still goes up); critical ones break through. Each arrival
// is announced (`arrived`), so the reef's nearest jelly can flare.
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    property var queue: []           // waiting for the island, oldest first
    readonly property var current: queue[0] ?? null
    readonly property int lifetime: 4000
    signal arrived(var n)

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

    // grouped by app for the control centre, newest group first
    readonly property var groups: {
        const map = {};
        const order = [];
        for (let i = all.length - 1; i >= 0; i--) {
            const n = all[i];
            const key = n.appName || "Notifications";
            if (!map[key]) {
                map[key] = { app: key, icon: n.appIcon || n.desktopEntry, items: [] };
                order.push(key);
            }
            map[key].items.push(n);
        }
        return order.map(k => map[k]);
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
        inlineReplySupported: true

        onNotification: n => {
            n.tracked = true;
            const breaksThrough = n.urgency === NotificationUrgency.Critical;
            if (!Shell.dnd || breaksThrough)
                root.queue = [...root.queue, n];
            root.arrived(n);
            n.closed.connect(() => root.done(n));
        }
    }
}
