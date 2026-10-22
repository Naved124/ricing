pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.chars
import qs.common
import qs.services

// The system card, as an animator's timesheet (タイムシート), on the desktop
// under the windows. A glass sheet headed "CUT <day of the year>": a column
// of frame numbers and three exposure columns, CPU (the accent), MEM (the
// second accent) and DSK, each inked from the top down as far as its value
// goes (the last cell pencil-hatched), with a red current-frame line stepping
// down a row a second. On the right the CPU large in Dela Gothic One, memory
// used of total and the disk's free space. The dancer stands small on its top
// edge, idling, and fans itself when the CPU has run hot for a few seconds.
// Drag it anywhere: it stays where it's dropped (Shell.statsAt, in
// settings.json); right-click puts it away and the control centre's
// Timesheet tile brings it back. Fed by Sys (one reader); between its
// updates and the playhead's step nothing redraws but the little dancer
// (15 fps, stopped while windows cover the card).
PanelWindow {
    id: win

    screen: Quickshell.screens[0] ?? null
    readonly property var monitor: Hypr.monitorFor(screen)

    visible: Shell.statsShown && !Hypr.fullscreenOn(monitor)

    // the free area: below the bar
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "satsuei-stats"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: card }

    readonly property int margin: 14
    readonly property int headroom: 58      // the little dancer stands above the card

    // the values, eased so a cell inks in rather than jumping
    property real cpu: Sys.cpu
    property real mem: Sys.mem
    property real disk: Sys.disk
    Behavior on cpu { NumberAnimation { duration: Style.durMove; easing.type: Easing.OutCubic } }
    Behavior on mem { NumberAnimation { duration: Style.durMove; easing.type: Easing.OutCubic } }
    Behavior on disk { NumberAnimation { duration: Style.durMove; easing.type: Easing.OutCubic } }

    function gb(bytes) { return (bytes / 1073741824).toFixed(bytes >= 1e11 ? 0 : 1); }

    // the playhead steps down the ten frames, once a second
    property int frame: 0
    Timer {
        interval: 1000
        repeat: true
        running: win.visible && !Motion.reduced
        onTriggered: win.frame = (win.frame + 1) % 10
    }

    // running hot: above 80% for 3 s; cool again after 3 s under 70%
    property bool hot: false
    property int streak: 0
    Timer {
        interval: 1000
        repeat: true
        running: win.visible
        onTriggered: {
            const v = Sys.cpu;
            if (win.hot ? v < 0.7 : v > 0.8) win.streak++;
            else win.streak = 0;
            if (win.streak >= 3) {
                win.hot = !win.hot;
                win.streak = 0;
            }
        }
    }

    // the card is out of sight when a window on this workspace covers it
    readonly property bool covered: {
        const ws = monitor?.activeWorkspace?.id ?? -1;
        const ox = (screen?.x ?? 0) + (screen ? screen.width - width : 0);
        const oy = (screen?.y ?? 0) + (screen ? screen.height - height : 0);
        const x0 = ox + card.x, y0 = oy + card.y - headroom, x1 = x0 + card.width, y1 = oy + card.y + card.height;
        return Windows.onWorkspace(ws).some(w => w.x <= x0 && w.y <= y0 && w.x + w.w >= x1 && w.y + w.h >= y1);
    }

    Item {
        id: card
        width: 300
        height: 204

        x: win.margin + Shell.statsAt.x * Math.max(0, win.width - width - 2 * win.margin)
        y: win.headroom + win.margin + Shell.statsAt.y * Math.max(0, win.height - height - win.headroom - 2 * win.margin)
        scale: drag.active ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: Style.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.settle } }

        DragHandler {
            id: drag
            cursorShape: Qt.ClosedHandCursor
            xAxis.minimum: win.margin; xAxis.maximum: win.width - card.width - win.margin
            yAxis.minimum: win.headroom + win.margin; yAxis.maximum: win.height - card.height - win.margin
            onActiveChanged: if (!active) {
                Shell.setStatsAt((card.x - win.margin) / Math.max(1, win.width - card.width - 2 * win.margin),
                                 (card.y - win.headroom - win.margin) / Math.max(1, win.height - card.height - win.headroom - 2 * win.margin));
                card.x = Qt.binding(() => win.margin + Shell.statsAt.x * Math.max(0, win.width - card.width - 2 * win.margin));
                card.y = Qt.binding(() => win.headroom + win.margin
                                          + Shell.statsAt.y * Math.max(0, win.height - card.height - win.headroom - 2 * win.margin));
            }
        }
        HoverHandler { cursorShape: Qt.OpenHandCursor }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: Shell.setStatsShown(false)
        }

        Glass {
            anchors.fill: parent
            radius: Style.radiusPanel
        }

        // ── the header: CUT and the day, the sheet's name ───────────────────
        Label {
            x: 14
            y: 9
            height: 18
            display: true
            size: 14
            spacing: 0.08
            text: {
                const d = new Date(), start = new Date(d.getFullYear(), 0, 0);
                return "CUT " + String(Math.floor((d - start) / 864e5)).padStart(3, "0");
            }
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 9
            height: 18
            size: 11.5
            weight: Style.weightStrong
            spacing: 0.1
            color: Theme.fgDim
            text: "タイムシート"
        }
        Rectangle { x: 12; y: 32; width: parent.width - 24; height: 1; color: Theme.rim }

        // ── the sheet ───────────────────────────────────────────────────────
        Item {
            id: sheet
            x: 12
            y: 40
            width: 150
            height: 144

            readonly property int numW: 18
            readonly property int colW: 40
            readonly property int headH: 16
            readonly property real rowH: (height - headH) / 10
            readonly property var cols: [
                { name: "CPU", v: win.cpu, ink: Theme.accent },
                { name: "MEM", v: win.mem, ink: Theme.accent2 },
                { name: "DSK", v: win.disk, ink: Theme.at(Theme.fg, 0.6) }
            ]

            // frame numbers
            Repeater {
                model: 10
                delegate: Label {
                    required property int index
                    x: 0
                    y: sheet.headH + index * sheet.rowH
                    width: sheet.numW - 4
                    height: sheet.rowH
                    horizontalAlignment: Text.AlignRight
                    mono: true
                    size: 8.5
                    color: index === win.frame ? Theme.urgent : Theme.fgDim
                    text: index + 1
                }
            }

            Repeater {
                model: sheet.cols
                delegate: Item {
                    id: column
                    required property var modelData
                    required property int index
                    x: sheet.numW + index * sheet.colW
                    width: sheet.colW
                    height: sheet.height

                    Label {
                        width: parent.width
                        height: sheet.headH
                        horizontalAlignment: Text.AlignHCenter
                        size: 9.5
                        weight: Style.weightStrong
                        spacing: 0.12
                        color: Theme.fgDim
                        text: column.modelData.name
                    }
                    // the column's frame and its cells
                    Rectangle {
                        y: sheet.headH
                        width: parent.width
                        height: sheet.height - sheet.headH
                        color: Theme.well
                        border.width: 1
                        border.color: Theme.rim
                    }
                    Repeater {
                        model: 10
                        delegate: Item {
                            id: cell
                            required property int index
                            readonly property real f: Math.max(0, Math.min(1, column.modelData.v * 10 - index))
                            x: 1
                            y: sheet.headH + index * sheet.rowH
                            width: column.width - 2
                            height: sheet.rowH
                            clip: true

                            // inked, or the last one pencilled: filled as far as
                            // the value goes, hatched across
                            Rectangle {
                                width: parent.width
                                height: cell.f >= 1 ? parent.height : parent.height * cell.f
                                color: column.modelData.ink
                                opacity: cell.f >= 1 ? 0.85 : 0.5
                                visible: cell.f > 0
                            }
                            Repeater {
                                model: cell.f > 0 && cell.f < 1 ? 6 : 0
                                delegate: Rectangle {
                                    required property int index
                                    x: index * 8 - 4
                                    y: -4
                                    width: 1.2
                                    height: cell.height * 1.8
                                    rotation: 35
                                    transformOrigin: Item.Top
                                    color: column.modelData.ink
                                }
                            }
                            // the grid's hairline under each frame
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: Theme.rim
                                visible: cell.index < 9
                            }
                        }
                    }
                }
            }

            // the current frame
            Rectangle {
                x: sheet.numW - 2
                y: sheet.headH + (win.frame + 0.5) * sheet.rowH
                width: 3 * sheet.colW + 4
                height: 1.5
                color: Theme.urgent
                opacity: 0.85
                Behavior on y {
                    enabled: win.frame !== 0
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Label {
                    anchors.left: parent.right
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    size: 10
                    color: Theme.urgent
                    text: "←"
                }
            }
        }

        // ── the readout ─────────────────────────────────────────────────────
        Column {
            x: sheet.x + sheet.width + 22
            y: 42
            width: card.width - x - 14
            spacing: 2

            Row {
                spacing: 2
                Label {
                    display: true
                    size: 38
                    text: Math.round(Sys.cpu * 100)
                }
                Label {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    display: true
                    size: 14
                    color: Theme.fgDim
                    text: "%"
                }
            }
            Label {
                size: 10
                weight: Style.weightStrong
                spacing: 0.12
                color: Theme.accent
                text: "CPU"
            }
            Item { width: 1; height: 8 }
            Label {
                size: 12
                weight: Style.weightStrong
                text: `${win.gb(Sys.memUsed)} / ${win.gb(Sys.memTotal)} G`
            }
            Label { size: 10; color: Theme.fgDim; text: "memory" }
            Item { width: 1; height: 3 }
            Label {
                size: 12
                weight: Style.weightStrong
                text: `${win.gb(Sys.diskFree)} G free`
            }
            Label { size: 10; color: Theme.fgDim; text: "disk, /" }
        }

        // ── the little dancer on the top edge ──────────────────────────────
        Item {
            id: perch
            x: card.width - 96
            y: -win.headroom + 3
            width: 48
            height: win.headroom

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -2
                width: 30
                height: 5
                radius: 2.5
                color: Theme.at(Theme.ink, 0.25)
            }
            Actor {
                anchors.fill: parent
                cast: Characters.dancer
                interval: 66
                mode: win.hot ? "wave" : "idle"
                running: win.visible && !win.covered
            }
        }
    }
}
