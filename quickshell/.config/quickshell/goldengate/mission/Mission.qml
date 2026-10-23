pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.services

// Mission Control (all of this Space's windows) and App Exposé (the front
// app's): the windows laid out without overlap, each a still of itself
// taken as it opens, its title on hover; the Spaces along the top, "+"
// for a new one. Click a window to go to it, a Space to switch, drag a
// window onto a Space to send it there. The stills are taken once and the
// captures dropped (a capture left open stalls grim and the lock screen).
Panel {
    id: root

    readonly property bool expose: Shell.open === "expose"
    readonly property var wins: {
        const here = Windows.onWorkspace(Windows.activeWorkspace);
        return expose ? Windows.regular.filter(w => w.class === Windows.activeClass) : here;
    }
    readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(wins.length * 1.6)))
    readonly property int rows: Math.max(1, Math.ceil(wins.length / cols))

    name: expose ? "expose" : "mission"
    part: "missioncontrol"
    dim: true
    paneWidth: screen ? screen.width : 1920
    paneHeight: screen ? screen.height : 1080
    pane.radius: 0
    pane.shadow: false

    // the Spaces
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18; spacing: 14
        visible: !root.expose
        Repeater {
            model: Hyprland.workspaces.values.filter(w => w.id > 0)
            delegate: Rectangle {
                id: sp
                required property var modelData
                width: 150; height: 88; radius: 10
                color: Theme.fill
                border.width: modelData.id === Windows.activeWorkspace ? 2 : 0
                border.color: Theme.accent
                Label { anchors.centerIn: parent; text: qsTr("Desktop %1").arg(sp.modelData.id) }
                DropArea {
                    anchors.fill: parent
                    onDropped: d => Hypr.dispatch(`hl.dsp.window.move({ workspace = ${sp.modelData.id}, follow = false, window = "address:${d.source.address}" })`, "")
                }
                TapHandler { onTapped: { Hypr.focusWorkspace(sp.modelData.id); Shell.closeAll(); } }
            }
        }
        Rectangle {
            width: 88; height: 88; radius: 10
            color: Theme.fill
            Label { anchors.centerIn: parent; text: "+"; font.pixelSize: 28 }
            TapHandler { onTapped: { Hypr.dispatch(`hl.dsp.focus({ workspace = "emptym" })`, ""); Shell.closeAll(); } }
        }
    }

    Grid {
        id: grid
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: root.expose ? 80 : 140 }
        columns: root.cols
        spacing: 28
        readonly property real cellW: Math.min(560, (root.paneWidth - 120) / root.cols - 28)
        readonly property real cellH: Math.min(380, (root.paneHeight - anchors.topMargin - 60) / root.rows - 28)

        Repeater {
            model: root.shown ? root.wins : []
            delegate: Item {
                id: cell
                required property var modelData
                readonly property string address: modelData.address
                readonly property real s: Math.min(grid.cellW / modelData.size[0], grid.cellH / modelData.size[1])
                width: grid.cellW; height: grid.cellH
                Drag.active: drag.active
                Drag.source: cell
                Drag.hotSpot: Qt.point(width / 2, height / 2)

                Rectangle {
                    id: frame
                    anchors.centerIn: parent
                    width: cell.modelData.size[0] * cell.s
                    height: cell.modelData.size[1] * cell.s
                    radius: 12
                    color: Theme.window
                    border.width: hov.hovered ? 3 : 0
                    border.color: Theme.accent
                    clip: true
                    Image { id: still; anchors.fill: parent; fillMode: Image.PreserveAspectFit; cache: false }
                    Loader {
                        id: cap
                        anchors.fill: parent
                        active: true
                        sourceComponent: ScreencopyView {
                            captureSource: Hyprland.toplevels.values.find(t => "0x" + t.address === cell.address)?.wayland ?? null
                            live: false
                            onHasContentChanged: if (hasContent) grabToImage(r => { still.source = r.url; cap.active = false; })
                        }
                        Timer { running: cap.active; interval: 2000; onTriggered: cap.active = false }
                    }
                    AppIcon { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -12 } implicitSize: 48; app: cell.modelData.class }
                }
                Rectangle {
                    visible: hov.hovered
                    anchors { horizontalCenter: parent.horizontalCenter; top: frame.bottom; topMargin: 14 }
                    width: Math.min(t.implicitWidth + 20, cell.width); height: 24; radius: 12
                    color: Theme.glassThick
                    Label { id: t; anchors.centerIn: parent; width: parent.width - 20; text: cell.modelData.title; font.pixelSize: Theme.smallSize; horizontalAlignment: Text.AlignHCenter }
                }
                HoverHandler { id: hov }
                DragHandler { id: drag; onActiveChanged: if (!active) { cell.Drag.drop(); cell.x = 0; cell.y = 0; } }
                TapHandler { onTapped: { Windows.focusWindow(cell.modelData); Shell.closeAll(); } }
            }
        }
    }
    Label {
        anchors.centerIn: parent
        visible: root.wins.length === 0
        text: root.expose ? qsTr("No windows") : qsTr("No windows on this desktop")
        color: Theme.onWallpaper
    }
}
