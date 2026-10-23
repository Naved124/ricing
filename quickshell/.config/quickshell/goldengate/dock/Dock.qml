pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.services

// The Dock: pinned apps, then running ones that aren't pinned, a divider,
// minimized windows, and the Trash. Icons magnify under the pointer, bounce
// while an app starts, and carry a dot while it runs. A click brings the
// app forward (its hidden or minimized windows back) or starts it; right
// click: Quit, or Keep in / Remove from Dock.
PanelWindow {
    id: root

    readonly property int size: Settings.dock.size
    readonly property int bigSize: Settings.dock.magnify && !Theme.reduceMotion ? Settings.dock.magnifySize : size
    readonly property bool hiddenForFullscreen: Hypr.fullscreenOn(Hypr.monitorFor(screen))
    readonly property bool autohide: Settings.dock.autohide
    readonly property bool raised: !autohide || hoverAll.hovered || Shell.open === "dockmenu"
    property real pointerX: -1000
    property string bouncing: ""
    property string menuFor: ""

    readonly property var pinned: Settings.dock.pinned
    readonly property var apps: {
        const list = pinned.map(id => ({ id: id, cls: classFor(id) }));
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
    function setPinned(list) { Shell.gg(["set", "dock.pinned", JSON.stringify(list)]); }

    anchors { bottom: true; left: true; right: true }
    implicitHeight: bigSize + 28
    exclusiveZone: autohide || hiddenForFullscreen ? 0 : size + 18
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "goldengate:dock"
    color: "transparent"
    visible: !hiddenForFullscreen
    mask: Region { item: raised ? pane : edge }

    Item { id: edge; anchors.bottom: parent.bottom; width: parent.width; height: 3 }
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
                    required property var modelData
                    app: modelData.id
                    running: root.isRunning(modelData)
                    bounce: root.bouncing === modelData.id
                    onActivated: root.open(modelData)
                    onMenu: { root.menuFor = modelData.id; menu.cls = modelData.cls; Shell.toggle("dockmenu"); }
                }
            }
            Rectangle { width: 1; height: root.size * 0.8; anchors.bottom: parent.bottom; anchors.bottomMargin: root.size * 0.1; color: Theme.separator }
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
                app: "user-trash" + (trash.full ? "-full" : "")
                running: false
                onActivated: Shell.run(["xdg-open", "trash:///"])
                onMenu: Shell.run(["gio", "trash", "--empty"])
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

    // right click: a small glass menu over the icon
    GlassPane {
        id: menu
        property string cls: ""
        readonly property bool pinned: root.pinned.includes(root.menuFor)
        visible: Shell.open === "dockmenu"
        anchors.horizontalCenter: parent.horizontalCenter
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
                model: [
                    { t: qsTr("New Window"), go: () => { const e = DesktopEntries.heuristicLookup(root.menuFor); if (e) e.execute(); } },
                    { t: menu.pinned ? qsTr("Remove from Dock") : qsTr("Keep in Dock"),
                      go: () => root.setPinned(menu.pinned ? root.pinned.filter(p => p !== root.menuFor) : root.pinned.concat([root.menuFor])) },
                    { t: qsTr("Show All Windows"), go: () => Shell.gg(["expose"]) },
                    { t: qsTr("Quit"), go: () => { for (const w of Windows.ofClass(menu.cls)) Hypr.dispatch(`hl.dsp.window.close({ window = "address:${w.address}" })`, ""); } },
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: items.width; height: 26; radius: 6
                    color: mh.containsMouse ? Theme.accent : "transparent"
                    Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.t; color: mh.containsMouse ? Theme.onAccent : Theme.label }
                    MouseArea { id: mh; anchors.fill: parent; hoverEnabled: true; onClicked: { parent.modelData.go(); Shell.closeAll(); } }
                }
            }
        }
    }
}
