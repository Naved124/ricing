import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The eyecatch: on every episode (workspace) change, a large "EP 0n" in Dela
// Gothic One and its label, spaced out in capitals in the accent, at the
// bottom left of that screen. It rises in (0.4 s fade, 0.5 s lift), holds for
// 1.3 s and fades. The labels are settings.json's `episodes` (Terminal,
// Notes, Wallpaper, Web, Music unless changed). It takes no input.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property var monitor: Hypr.monitorFor(screen)
    // set once, then only by the handler: a binding would already have moved
    // on when the change arrives
    property int shownId: 1
    property int lastId: 0
    property bool show: false
    Component.onCompleted: lastId = shownId = monitor?.activeWorkspace?.id ?? 1

    anchors { bottom: true; left: true }
    margins { left: 28; bottom: 40 }
    implicitWidth: 520
    implicitHeight: 110
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "satsuei-eyecatch"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    visible: col.opacity > 0 || show

    function label(id) {
        const eps = Settings.s.episodes ?? [];
        return eps[id - 1] ?? "";
    }

    Connections {
        target: win.monitor
        function onActiveWorkspaceChanged() {
            const id = win.monitor?.activeWorkspace?.id ?? 0;
            if (id <= 0 || id === win.lastId) return;
            win.lastId = id;
            win.shownId = id;
            win.show = true;
            hold.restart();
        }
    }
    Timer {
        id: hold
        interval: 1300 + 400
        onTriggered: win.show = false
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: win.show ? 0 : -12
        opacity: win.show ? 1 : 0
        spacing: 6
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        Label {
            text: "EP " + String(win.shownId).padStart(2, "0")
            display: true
            size: 64
            spacing: 0.02
            style: Text.Raised
            styleColor: Theme.at(Theme.ink, 0.4)
        }
        Label {
            visible: text !== ""
            text: win.label(win.shownId).toUpperCase()
            size: 12
            weight: 800
            spacing: 0.3
            color: Theme.accent
            style: Text.Raised
            styleColor: Theme.at(Theme.ink, 0.5)
        }
    }
}
