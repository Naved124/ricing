pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Paper is the notification daemon (no swaync). Notifications become sticky
// notes: at most three on the desk at once, newest on top; more wait in a
// queue and are slapped on as notes are peeled off. Everything is kept for
// the control centre's history until dismissed.
// Do Not Disturb keeps notes off the desk (they only go to the history);
// critical ones still come through, and never time out.
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    property var shown: []           // on the desk, newest first (≤ maxVisible)
    property var queue: []           // waiting for a free spot, oldest first
    readonly property int maxVisible: 3

    // how long a note stays up, in ms; 0 = until dismissed
    function lifetime(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        if (n.expireTimeout > 0) return Math.max(2000, n.expireTimeout);
        return n.urgency === NotificationUrgency.Low ? 4000 : 6500;
    }

    // the note left the desk (peeled, timed out or the app closed it):
    // the next one in the queue takes its place
    function unshow(n) {
        if (shown.includes(n)) {
            const rest = shown.filter(p => p !== n);
            if (queue.length) {
                shown = [queue[0], ...rest];
                queue = queue.slice(1);
            } else {
                shown = rest;
            }
        } else if (queue.includes(n)) {
            queue = queue.filter(p => p !== n);
        }
    }

    function dismiss(n) {
        unshow(n);
        n.dismiss();
    }

    function clearAll() {
        shown = [];
        queue = [];
        for (const n of all.slice()) n.dismiss();
    }

    function post(n) {
        if (shown.length < maxVisible) shown = [n, ...shown];
        else queue = [...queue, n];
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
                root.post(n);
            n.closed.connect(() => root.unshow(n));
        }
    }
}
