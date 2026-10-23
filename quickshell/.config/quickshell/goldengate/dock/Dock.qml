pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.services

// The Dock: pinned apps, then running ones that aren't pinned, a divider,
// minimized windows, and the Trash. Icons magnify under the pointer, bounce
// while an app starts, and carry a dot while it runs. A click brings the
// app forward (its hidden or minimized windows back) or starts it; right
// click: Quit, or Keep in / Remove from Dock. It dodges windows: while one on
// this screen's workspace reaches down into it, it slides away until the
// pointer touches the bottom edge, so it reserves no space.
PanelWindow {
    id: root

    readonly property int size: Settings.dock.size
    readonly property int bigSize: Settings.dock.magnify && !Theme.reduceMotion ? Settings.dock.magnifySize : size
    // the screen's name, given once (reading `screen` here loops as the window maps)
    property string at: ""
    readonly property bool hiddenForFullscreen: Hypr.fullscreenOn(Hyprland.monitors.values.find(m => m.name === at) ?? null)
    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === at) ?? null
    readonly property bool menuShown: Shell.open === "dockmenu"
    // a window on this screen's workspace over the Dock's strip
    readonly property bool covered: {
        const m = monitor;
        if (!m || !m.activeWorkspace) return false;
        const sc = m.scale || 1, mh = m.height / sc, mw = m.width / sc;
        const top = m.y + mh - (size + 24), half = pane.width / 2 + 8, cx = m.x + mw / 2;
        return Windows.regular.some(w => w.workspace.id === m.activeWorkspace.id
            && w.at[1] + w.size[1] > top && w.at[0] < cx + half && w.at[0] + w.size[0] > cx - half);
    }
    readonly property bool wanted: !covered || hoverAll.hovered || menuShown
    // down only after a moment, so passing the pointer over the edge doesn't flicker it
    property bool raised: true
    onWantedChanged: if (wanted) { lower.stop(); raised = true; } else lower.restart()
    Timer { id: lower; interval: 450; onTriggered: root.raised = root.wanted }
    // a floating window moved or resized sends no event: look again now and then
    Timer { interval: 1500; running: !hoverAll.hovered; repeat: true; onTriggered: Windows.refresh() }
    property real pointerX: -1000
    property string bouncing: ""
    property string menuFor: ""

    readonly property var pinned: Settings.dock.pinned
    // pinned apps that are installed, then running ones that aren't pinned
    readonly property var apps: {
        const list = pinned.filter(id => DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id))
                           .map(id => ({ id: id, cls: classFor(id) }));
        for (const cls of Windows.running)
            if (!list.some(a => a.cls === cls || a.id === cls)) list.push({ id: cls, cls: cls });
        return list;
    }
    function classFor(id) {
        const e = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
        return e && e.startupClass ? e.startupClass : id;
    }
    function isRunning(a) { return Windows.running.some(c => c === a.cls || c === a.id || c.toLowerCase() === a.id.toLowerCase()); }
    function open(a) {
        if (Windows.activate(Windows.running.find(c => c === a.cls || c === a.id || c.toLowerCase() === a.id.toLowerCase()) || a.cls)) return;
        const e = DesktopEntries.byId(a.id) || DesktopEntries.heuristicLookup(a.id);
        if (e) { e.execute(); bouncing = a.id; bounceEnd.restart(); }
    }
    Timer { id: bounceEnd; interval: 2400; onTriggered: root.bouncing = "" }
    function setPinned(list) { Settings.set("dock.pinned", list); }

    anchors { bottom: true; left: true; right: true }
    // room above the magnified icons for the name over the hovered one, and for the menu
    implicitHeight: Math.max(bigSize + 72, size + 190)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "goldengate:dock"
    color: "transparent"
    // the pane (and the strip under it, so the pointer never falls between),
    // the bottom edge while it's away, the menu while it's open
    mask: Region {
        item: root.raised ? pane : edge
        Region { item: edge }
        Region { x: menu.x; y: menu.y; width: root.menuShown ? menu.width : 0; height: root.menuShown ? menu.height : 0 }
    }

    Item {
        id: edge
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: root.raised ? pane.width : parent.width
        height: root.raised ? 10 : 2
    }
    HoverHandler { id: hoverAll }

    GlassPane {
        id: pane
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.raised ? parent.height - height - 8 : parent.height + 4
        Behavior on y { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }
        width: row.width + 16
        height: root.size + 12
        radius: Math.min(26, height * 0.38)
        screen: root.screen
        windowOrigin: Qt.point(0, (root.screen ? root.screen.height : 1080) - root.implicitHeight)

        HoverHandler {
            id: paneHover
            onPointChanged: root.pointerX = point.position.x
            onHoveredChanged: if (!hovered) root.pointerX = -1000
        }

        Row {
            id: row
            x: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            spacing: 4

            Repeater {
                model: root.apps
                delegate: DockIcon {
                    id: appIcon
                    required property var modelData
                    app: modelData.id
                    running: root.isRunning(modelData)
                    bounce: root.bouncing === modelData.id
                    onActivated: root.open(modelData)
                    onMenu: root.showMenu(modelData.id, modelData.cls, appIcon)
                }
            }
            Rectangle { width: 1; height: root.size * 0.7; anchors.bottom: parent.bottom; anchors.bottomMargin: root.size * 0.15; color: Theme.label3 }
            Repeater {
                model: Windows.minimized
                delegate: DockIcon {
                    required property var modelData
                    app: modelData.class
                    running: false
                    onActivated: Windows.restore(modelData)
                }
            }
            DockIcon {
                id: trashIcon
                app: "user-trash" + (trash.full ? "-full" : "")
                running: false
                onActivated: Shell.run(["nautilus", "--new-window", "trash:///"])
                onMenu: root.showMenu("trash", "", trashIcon)
                Process { id: trashCheck; running: true; command: ["sh", "-c", "ls -A ~/.local/share/Trash/files 2>/dev/null | head -c1"]; stdout: StdioCollector { onStreamFinished: trash.full = this.text.length > 0 } }
                QtObject { id: trash; property bool full: false }
                Timer { interval: 5000; running: true; repeat: true; onTriggered: trashCheck.running = true }
            }
        }
    }

    // an icon: its size swells with the pointer's nearness
    component DockIcon: Item {
        id: icon
        property string app
        property bool running
        property bool bounce
        signal activated()
        signal menu()
        readonly property real centre: x + width / 2 + row.x
        readonly property real near: Math.max(0, 1 - Math.abs(root.pointerX - centre) / (root.size * 2.2))
        readonly property real now: root.size + (root.bigSize - root.size) * near * near
        width: now
        height: now
        anchors.bottom: parent ? parent.bottom : undefined
        Behavior on width { enabled: !Theme.reduceMotion; NumberAnimation { duration: 90 } }

        AppIcon {
            id: img
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            app: icon.app
            implicitSize: icon.now
            SequentialAnimation on y {
                running: icon.bounce && !Theme.reduceMotion
                loops: 3
                NumberAnimation { to: -root.size * 0.45; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0; duration: 260; easing.type: Easing.InQuad }
            }
        }
        Rectangle {
            visible: icon.running
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 1 }
            width: 4; height: 4; radius: 2
            color: Theme.label
        }
        Rectangle {
            visible: hov.hovered
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 8 }
            width: tip.implicitWidth + 18; height: 24; radius: 8
            color: Theme.glassThick
            border.color: Theme.glassEdge
            Label { id: tip; anchors.centerIn: parent; text: Windows.appName(icon.app); font.pixelSize: Theme.smallSize }
        }
        HoverHandler { id: hov }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => e.button === Qt.RightButton ? icon.menu() : icon.activated()
        }
    }

    function showMenu(id, cls, icon) {
        if (menuShown && menuFor === id) { Shell.closeAll(); return; }
        menuFor = id;
        menu.cls = cls;
        menu.atX = icon.mapToItem(null, icon.width / 2, 0).x;
        Shell.toggle("dockmenu");
    }
    // what the menu offers: the Trash's, or an app's
    readonly property var menuItems: menuFor === "trash" ? [
        { t: qsTr("Open"), go: () => Shell.run(["nautilus", "--new-window", "trash:///"]) },
        { t: qsTr("Empty Trash"), go: () => Shell.run(["gio", "trash", "--empty"]) },
    ] : [
        { t: qsTr("New Window"), go: () => { const e = DesktopEntries.byId(root.menuFor) || DesktopEntries.heuristicLookup(root.menuFor); if (e) e.execute(); } },
        { t: menu.pinned ? qsTr("Remove from Dock") : qsTr("Keep in Dock"),
          go: () => root.setPinned(menu.pinned ? root.pinned.filter(p => p !== root.menuFor) : root.pinned.concat([root.menuFor])) },
        { t: qsTr("Show All Windows"), go: () => Shell.gg(["expose"]), off: !root.isRunning({ id: root.menuFor, cls: menu.cls }) },
        { t: qsTr("Quit"), go: () => Shell.gg(["win", "quit-app", menu.cls || root.menuFor]), off: !root.isRunning({ id: root.menuFor, cls: menu.cls }) },
    ].filter(i => !i.off)
    // the menu closes when the pointer has left it (and the Dock) for a moment
    Timer { running: root.menuShown && !hoverAll.hovered; interval: 1800; onTriggered: Shell.closeAll() }

    // right click: a small glass menu over the icon
    GlassPane {
        id: menu
        property string cls: ""
        property real atX: root.width / 2
        readonly property bool pinned: root.pinned.includes(root.menuFor)
        visible: root.menuShown
        x: Math.max(8, Math.min(root.width - width - 8, atX - width / 2))
        anchors.bottom: pane.top
        anchors.bottomMargin: 8
        width: 200
        height: items.implicitHeight + 12
        radius: 12
        thick: true
        screen: root.screen
        Column {
            id: items
            anchors { fill: parent; margins: 6 }
            Repeater {
                model: root.menuItems
                delegate: Rectangle {
                    required property var modelData
                    width: items.width; height: 26; radius: 6
                    color: mh.containsMouse ? Theme.accent : "transparent"
                    Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.t; color: mh.containsMouse ? Theme.onAccent : Theme.label }
                    MouseArea { id: mh; anchors.fill: parent; hoverEnabled: true; onClicked: { const go = parent.modelData.go; Shell.closeAll(); go(); } }
                }
            }
        }
    }
}
