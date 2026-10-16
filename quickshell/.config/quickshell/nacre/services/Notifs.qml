pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Nacre is the notification daemon (no swaync, no mako).
// Every notification is kept for the control centre until dismissed;
// popups are a separate, short-lived list. Do Not Disturb silences popups
// but still collects everything, and critical notifications break through.
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    property var popups: []          // Notification objects currently popped up
    readonly property int maxVisible: 3

    // seconds a popup stays up, by urgency (critical stays until dismissed)
    function lifetime(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        if (n.urgency === NotificationUrgency.Low) return 3000;
        return 5000;
    }

    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
    }

    function dismiss(n) {
        hidePopup(n);
        n.dismiss();
    }

    function clearAll() {
        popups = [];
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
                root.popups = [n, ...root.popups];
            n.closed.connect(() => root.hidePopup(n));
        }
    }
}
