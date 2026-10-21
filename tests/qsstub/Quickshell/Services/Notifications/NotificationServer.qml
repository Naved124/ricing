// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
import Quickshell
QtObject {
    id: root
    property bool keepOnReload: true
    property bool persistenceSupported: false
    property bool bodySupported: true
    property bool bodyMarkupSupported: false
    property bool bodyHyperlinksSupported: false
    property bool bodyImagesSupported: false
    property bool actionsSupported: false
    property bool actionIconsSupported: false
    property bool imageSupported: false
    property bool inlineReplySupported: false
    property var extraHints: []
    property QsObjectModel trackedNotifications: QsObjectModel {}
    signal notification(var n)
    // the smoke test sends one through
    function fake(urgency) {
        const n = Qt.createQmlObject('import Quickshell.Services.Notifications; Notification {}', root);
        n.urgency = urgency ?? 1;
        notification(n);
        if (n.tracked) trackedNotifications.values = trackedNotifications.values.concat([n]);
        n.closed.connect(() => trackedNotifications.values = trackedNotifications.values.filter(x => x !== n));
        return n;
    }
    Component.onCompleted: Qt.callLater(() => { fake(1); fake(2); })
}
