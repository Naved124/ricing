pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.services

// ⌥Tab: the windows of this Space, most recently used first, as icons with
// their titles on one glass strip. Each ⌥Tab (⌥⇧Tab back) moves the choice;
// letting go of ⌥ brings the chosen window forward. Esc or a click outside
// leaves things as they were; a click on one picks it.
PanelWindow {
    id: root

    // the screen's name, given once (reading `screen` here loops as the window maps)
    property string at: ""
    readonly property bool shown: Shell.open === "switcher" && (Shell.openScreen === "" || at === "" || Shell.openScreen === at)
    property var list: []
    property int index: 0

    // what Shell.switcher() calls on every press of the bind
    function step(by) {
        if (!shown) {
            const m = Hyprland.monitors.values.find(x => x.name === at);
            const ws = m && m.activeWorkspace ? m.activeWorkspace.id : -1;
            list = Windows.regular.filter(w => w.workspace.id === ws).sort((a, b) => a.focusHistoryID - b.focusHistoryID);
            if (list.length < 2) { if (list.length === 1) Windows.focusWindow(list[0]); return; }
            index = by > 0 ? 1 : list.length - 1;
            Shell.toggle("switcher");
            return;
        }
        index = (index + by + list.length) % list.length;
    }
    // the strip goes first: while it holds the keyboard, Hyprland would hand
    // the focus back to the window it was taken from
    function pick() {
        chosen = list[index] || null;
        Shell.closeAll();
        if (chosen) raiseLater.restart();
    }
    property var chosen: null
    Timer { id: raiseLater; interval: 90; onTriggered: if (root.chosen) Shell.gg(["win", "raise", root.chosen.address]) }

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
        width: Math.min(root.width - 80, row.implicitWidth + 28)
        height: 196
        radius: 28
        thick: true
        screen: root.screen
        focus: root.shown
        Keys.onReleased: e => { if (e.key === Qt.Key_Alt || e.key === Qt.Key_AltGr) root.pick(); }
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) Shell.closeAll();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.pick();
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.step(1);
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) root.step(-1);
        }
        MouseArea { anchors.fill: parent; z: -1 }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: root.list
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === root.index
                    width: 132; height: 168; radius: 18
                    color: chosen ? Theme.fillHover : "transparent"
                    border.width: chosen ? 1 : 0
                    border.color: Theme.glassEdge
                    AppIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        app: cell.modelData.class
                        implicitSize: 88
                    }
                    Label {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10; bottomMargin: 12 }
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.title || Windows.appName(cell.modelData.class)
                        font.pixelSize: Theme.smallSize
                        strong: cell.chosen
                        secondary: !cell.chosen
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
    }
    onShownChanged: if (shown) strip.forceActiveFocus()
}
