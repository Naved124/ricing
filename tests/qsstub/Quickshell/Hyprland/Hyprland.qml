// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

pragma Singleton
import QtQuick
import Quickshell
Item {
    id: root
    // workspaces are plain objects: QML can't declare a property called `id`
    property var ws1: ({ id: 1, name: "1", active: true, focused: true, urgent: false, hasFullscreen: false,
                         toplevels: { values: [] }, lastIpcObject: ({}), monitor: null, activate: () => {} })
    property var ws2: ({ id: 2, name: "2", active: false, focused: false, urgent: true, hasFullscreen: false,
                         toplevels: { values: [{ title: "kitty" }] }, lastIpcObject: ({}), monitor: null, activate: () => {} })
    property HyprlandMonitor m0: HyprlandMonitor { name: "DP-1"; activeWorkspace: root.ws1 }
    property HyprlandMonitor m1: HyprlandMonitor { name: "HDMI-A-1"; x: 1920; width: 2560; height: 1440; focused: false; activeWorkspace: root.ws2 }
    property QsObjectModel monitors: QsObjectModel { values: [root.m0, root.m1] }
    property QsObjectModel workspaces: QsObjectModel { values: [root.ws1, root.ws2] }
    Component.onCompleted: { ws1.monitor = m0; ws2.monitor = m0; }
    property QsObjectModel toplevels: QsObjectModel {}
    property var focusedMonitor: m0
    property var focusedWorkspace: ws1
    property var activeToplevel: null
    property bool usingLua: true
    signal rawEvent(var event)
    function dispatch(cmd) {}
    function monitorFor(screen) { return screen && screen.name === "HDMI-A-1" ? m1 : m0; }
    function refreshMonitors() {}
    function refreshWorkspaces() {}
    function refreshToplevels() {}
}
