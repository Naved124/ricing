pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.services

// ⌘Tab: every running app, one icon each, the most recently used first, on
// one glass strip with the chosen app's name under it. Each ⌘Tab (⌘⇧Tab
// back) moves the choice; letting go of ⌘ brings the app forward (its last
// window, wherever it is; a hidden or minimized app comes back). While the
// strip is up, Q quits the chosen app and Esc leaves things as they were.
// A quick ⌘Tab goes back to the previous app before the strip shows.
PanelWindow {
    id: root

    property string at: ""
    readonly property bool shown: Shell.open === "appswitcher" && (Shell.openScreen === "" || at === "" || Shell.openScreen === at)
    // [{ cls, window }]: the app and its most recently used window
    property var apps: []
    property int index: 0

    function gather() {
        const by = {};
        for (const w of Windows.all) {
            if (!w.mapped || !w.class || (w.workspace.name || "") === "special:desktop") continue;
            const was = by[w.class];
            if (!was || w.focusHistoryID < was.focusHistoryID) by[w.class] = w;
        }
        return Object.keys(by).map(c => ({ cls: c, window: by[c] }))
                     .sort((a, b) => a.window.focusHistoryID - b.window.focusHistoryID);
    }
    function step(by) {
        if (!shown) {
            apps = gather();
            if (apps.length === 0) return;
            index = apps.length < 2 ? 0 : (by > 0 ? 1 : apps.length - 1);
            Shell.toggle("appswitcher");
            return;
        }
        index = (index + by + apps.length) % apps.length;
    }
    property var chosen: null
    function pick() {
        chosen = apps[index] || null;
        Shell.closeAll();
        if (chosen) bringLater.restart();
    }
    function quitChosen() {
        const a = apps[index];
        if (!a) return;
        Shell.gg(["win", "quit-app", a.cls]);
        const rest = apps.slice();
        rest.splice(index, 1);
        if (rest.length === 0) { Shell.closeAll(); return; }
        apps = rest;
        index = Math.min(index, apps.length - 1);
    }
    // the strip lets go of the keyboard first, as ⌥Tab's does
    Timer {
        id: bringLater
        interval: 90
        onTriggered: {
            const a = root.chosen;
            if (!a) return;
            if ((a.window.workspace.name || "").startsWith("special:")) Windows.activate(a.cls);
            else Shell.gg(["win", "raise", a.window.address]);
        }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "goldengate:switcher"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: shown

    MouseArea { anchors.fill: parent; onClicked: Shell.closeAll() }

    GlassPane {
        id: strip
        anchors.centerIn: parent
        width: Math.min(root.width - 80, row.implicitWidth + 32)
        height: 150
        radius: 30
        thick: true
        screen: root.screen
        focus: root.shown
        // as on the Mac, a quick ⌘Tab never shows the strip
        opacity: 0
        Timer { id: reveal; interval: 120; onTriggered: strip.opacity = 1 }
        Behavior on opacity { NumberAnimation { duration: Theme.reduceMotion ? 0 : 120 } }

        Keys.onReleased: e => { if (e.key === Qt.Key_Meta || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R) root.pick(); }
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) Shell.closeAll();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.pick();
            else if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) root.step(-1);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.step(1);
            else if (e.key === Qt.Key_Left) root.step(-1);
            else if (e.key === Qt.Key_Q) root.quitChosen();
        }
        MouseArea { anchors.fill: parent; z: -1 }

        Row {
            id: row
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            spacing: 6
            Repeater {
                model: root.apps
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === root.index
                    width: 112; height: 112; radius: 22
                    color: chosen ? Theme.fillHover : "transparent"
                    border.width: chosen ? 1 : 0
                    border.color: Theme.glassEdge
                    AppIcon {
                        anchors.centerIn: parent
                        app: cell.modelData.cls
                        implicitSize: 88
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.index = cell.index
                        onClicked: root.pick()
                    }
                }
            }
        }
        Label {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
            width: parent.width - 32
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.apps[root.index] ? Windows.appName(root.apps[root.index].cls) : ""
            font.pixelSize: Theme.smallSize
            strong: true
        }
    }
    onShownChanged: {
        if (shown) { strip.opacity = 0; reveal.restart(); strip.forceActiveFocus(); }
        else reveal.stop();
    }
}
