pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The Notion card on the desk, under the windows, in every rice: what's due
// (overdue and today first), the next thing on the agenda, and a line to add
// a task ("call mum @tomorrow", "@fri", "@+3" or "@2026-11-02" sets its due date).
// Drag it by its header and it stays where it's dropped; right-click puts it
// away (the control centre's Notion tile brings it back); ↗ or a click on the
// title opens the whole of it (NotionPanel.qml). It hides while its monitor has
// a fullscreen window.
PanelWindow {
    id: win

    screen: Quickshell.screens[0] ?? null
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property bool fullscreen: !!monitor?.activeWorkspace?.hasFullscreen
    property real now: Date.now()

    visible: Notion.shown && !fullscreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "rice-notion"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: card }

    Timer { interval: 30000; repeat: true; running: win.visible; onTriggered: win.now = Date.now() }

    readonly property var due: Notion.filtered("open")
    readonly property int overdue: Notion.tasks.filter(t => t.overdue).length
    readonly property int dueToday: Notion.tasks.filter(t => t.today).length
    readonly property var next: {
        return Notion.agenda.find(a => a.allDay ? a.day >= Notion.today : new Date(a.end || a.start).getTime() >= win.now) ?? null;
    }

    // "milk @tomorrow" → { text: "milk", due: "tomorrow" }
    function parse(s) {
        const m = s.match(/^(.*?)\s+@(\S+)\s*$/);
        return m ? { text: m[1], due: m[2] } : { text: s, due: "" };
    }

    Rectangle {
        id: card
        width: 340
        height: body.implicitHeight + 32
        x: Notion.at.x * (win.width - width)
        y: Notion.at.y * (win.height - height)
        radius: NotionLook.radius
        color: Qt.alpha(NotionLook.role("surface"), 0.94)
        border.width: 1
        border.color: drag.active ? NotionLook.role("accent") : NotionLook.role("border")
        Behavior on border.color { ColorAnimation { duration: 200 } }
        scale: drag.active ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: NotionLook.bloom.concat([1, 1]) } }

        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: Notion.setShown(false)
        }

        Column {
            id: body
            x: 18; y: 16
            width: parent.width - 36
            spacing: 12

            // ── header: the mark, today, the sync, refresh and open ───────
            Item {
                id: header
                width: parent.width
                height: 34
                DragHandler {
                    id: drag
                    target: card
                    cursorShape: Qt.ClosedHandCursor
                    xAxis.minimum: 0; xAxis.maximum: win.width - card.width
                    yAxis.minimum: 0; yAxis.maximum: win.height - card.height
                    onActiveChanged: if (!active) {
                        Notion.setAt(card.x / Math.max(1, win.width - card.width),
                                     card.y / Math.max(1, win.height - card.height));
                        card.x = Qt.binding(() => Notion.at.x * (win.width - card.width));
                        card.y = Qt.binding(() => Notion.at.y * (win.height - card.height));
                    }
                }
                HoverHandler { cursorShape: Qt.OpenHandCursor }

                Rectangle {
                    id: mark
                    width: 30; height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    radius: NotionLook.chip
                    color: NotionLook.role("fg")
                    NotionText {
                        anchors.centerIn: parent
                        text: "N"
                        font.family: NotionLook.fontDisplay
                        size: 19
                        bold: true
                        color: NotionLook.role("bg")
                    }
                }
                Column {
                    anchors.left: mark.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    NotionText {
                        text: new Date(win.now).toLocaleDateString(Qt.locale(), "dddd")
                        font.family: NotionLook.fontDisplay
                        size: NotionLook.uiSize + 2
                        bold: true
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notion.panelOpen = true }
                    }
                    Row {
                        spacing: 6
                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6; radius: 3
                            color: !Notion.ok || Notion.error ? NotionLook.role("urgent")
                                 : Notion.busy || Notion.stale ? NotionLook.role("warning") : NotionLook.role("success")
                            SequentialAnimation on opacity {
                                running: Notion.busy && win.visible
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation { to: 0.25; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                        NotionText {
                            text: Notion.setup ? "not set up" : Notion.busy ? "syncing…"
                                : !Notion.ok ? "offline · " + Notion.ago(win.now) : "synced " + Notion.ago(win.now)
                            size: NotionLook.uiSize - 3
                            dim: true
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: [{ glyph: "⟳", tip: "refresh", act: () => Notion.refresh() },
                                { glyph: "↗", tip: "open", act: () => { Notion.panelOpen = true; } }]
                        delegate: Rectangle {
                            id: btn
                            required property var modelData
                            width: 28; height: 28
                            radius: NotionLook.chip
                            color: Qt.alpha(NotionLook.role("fg"), bm.containsMouse ? 0.1 : 0)
                            NotionText {
                                anchors.centerIn: parent
                                text: btn.modelData.glyph
                                size: NotionLook.uiSize + 1
                                dim: !bm.containsMouse
                                rotation: btn.modelData.tip === "refresh" && Notion.busy ? 360 : 0
                                Behavior on rotation { NumberAnimation { duration: 900 } }
                            }
                            MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.modelData.act() }
                        }
                    }
                }
            }

            // ── not set up yet ────────────────────────────────────────────
            NotionText {
                visible: Notion.setup || (!Notion.configured && Notion.ok && !Notion.stale)
                width: parent.width
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                size: NotionLook.uiSize - 1.5
                dim: true
                text: Notion.setup
                    ? "Add an integration token to ~/.config/rice/notion.toml (the example is in ~/.local/share/rice/notion.example.toml), then run rice-notion check."
                    : "No tasks database yet: set [tasks] database in ~/.config/rice/notion.toml."
            }

            // ── counts ────────────────────────────────────────────────────
            Row {
                visible: Notion.configured
                spacing: 6
                NotionChip { visible: win.overdue > 0; text: `${win.overdue} overdue`; tone: "urgent"; lit: true }
                NotionChip { text: `${win.dueToday} today`; tone: "accent" }
                NotionChip { text: `${Notion.tasks.length} open` }
            }

            // ── what's due ────────────────────────────────────────────────
            Column {
                visible: Notion.configured
                width: parent.width
                spacing: 0
                Repeater {
                    model: win.due.slice(0, 6)
                    delegate: NotionTask {
                        required property var modelData
                        width: parent.width
                        task: modelData
                        compact: true
                    }
                }
                NotionText {
                    visible: Notion.configured && !win.due.length
                    text: "Nothing open. Nice."
                    dim: true
                    size: NotionLook.uiSize - 1
                    height: 30
                }
                NotionText {
                    visible: win.due.length > 6
                    text: `+ ${win.due.length - 6} more`
                    dim: true
                    size: NotionLook.uiSize - 2.5
                    height: 22
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Notion.setTab("tasks"); Notion.panelOpen = true; } }
                }
            }

            // ── next on the agenda ────────────────────────────────────────
            Rectangle {
                visible: !!win.next
                width: parent.width
                height: 40
                radius: NotionLook.chip
                color: Qt.alpha(NotionLook.role("accent"), 0.1)
                Rectangle { x: 0; width: 3; height: parent.height - 14; anchors.verticalCenter: parent.verticalCenter; radius: 1.5; color: NotionLook.role("accent") }
                NotionText {
                    x: 12
                    width: parent.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.next ? `${win.next.icon ? win.next.icon + "  " : ""}${win.next.title}` : ""
                    size: NotionLook.uiSize - 1
                    bold: true
                }
                NotionText {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.next ? Notion.dayName(win.next.start) + (win.next.allDay ? "" : " " + Notion.timeOf(win.next.start)) : ""
                    size: NotionLook.uiSize - 2.5
                    dim: true
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notion.open(win.next.url) }
            }

            // ── add a task ────────────────────────────────────────────────
            NotionField {
                id: add
                visible: Notion.configured
                width: parent.width
                placeholder: "+ Add a task   (@tomorrow, @fri, @+3)"
                onAccepted: {
                    const p = win.parse(text);
                    Notion.add(p.text, p.due);
                    text = "";
                }
                onEscaped: text = ""
            }

            NotionText {
                visible: !!Notion.error && !Notion.setup
                width: parent.width
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                maximumLineCount: 3
                text: Notion.error
                color: NotionLook.role("urgent")
                size: NotionLook.uiSize - 3
            }
        }
    }
}
