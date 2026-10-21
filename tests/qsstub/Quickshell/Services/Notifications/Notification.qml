// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

import QtQuick
QtObject {
    property int id: 1
    property bool tracked: false
    property string appName: "kitty"
    property string appIcon: ""
    property string desktopEntry: "kitty"
    property string summary: "Build finished"
    property string body: "in 41s · 0 errors"
    property string image: ""
    property int urgency: 1
    property real expireTimeout: -1
    property bool hasInlineReply: true
    property string inlineReplyPlaceholder: "Reply"
    property bool resident: false
    property var actions: [Qt.createQmlObject('import Quickshell.Services.Notifications; NotificationAction {}', this)]
    property date time: new Date()
    signal closed(int reason)
    function dismiss() { tracked = false; closed(1); }
    function expire() { tracked = false; closed(0); }
    function sendInlineReply(t) {}
}
