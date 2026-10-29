pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// The Desk card: Notion on the desktop, under the windows, like the system
// card. Today's open tasks (the box ticks it in Notion), what's counting
// down, and the start of the daily brief. A click anywhere else opens the
// full view there (DeskView); drag it anywhere and it stays (ui.json, the
// same in every rice); right-click puts it away, the control centre's Desk
// tile brings it back. `hidden` is the shell's say (a fullscreen window).
//
// Resizing is Android's: hold the card for half a second and it gets an
// outline with a dot on each edge; drag a dot to make it any size, and a
// click outside (or Done) ends it. What fits is laid out again for the size:
// small shows the count and the next countdown, taller shows more rows and
// more of the brief, and from 620 wide Today and the rest sit side by side.
// Until it's first made taller or shorter its height follows what it holds.
PanelWindow {
    id: win

    property bool hidden: false
    readonly property bool resizing: DeskState.cardResizing

    readonly property real minW: 240
    readonly property real minH: 120
    readonly property real maxW: Math.min(900, width - 20)
    readonly property real maxH: height - 20

    screen: Quickshell.screens[0] ?? null
    visible: DeskState.cardShown && !hidden && !DeskState.viewOpen
    onVisibleChanged: if (!visible) DeskState.cardResizing = false

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: DeskTheme.cardNamespace

    // while resizing the whole screen listens, so a click outside ends it
    mask: Region { item: win.resizing ? cover : card }

    function open(what, id) {
        if (resizing) { DeskState.cardResizing = false; return; }
        DeskState.openView(win.screen?.name ?? "", what, id);
    }

    // "today", "overdue", a weekday within the week, else the date
    function when(t) {
        if (t.done) return "";
        if (t.state === "overdue") return "overdue";
        if (t.state === "today") return "today";
        if (!t.due) return "";
        const d = new Date(t.due + "T00:00:00");
        const days = Math.round((d - new Date(new Date(DeskState.now).toDateString())) / 86400000);
        return days === 1 ? "tomorrow" : days < 7 ? Qt.formatDate(d, "ddd") : Qt.formatDate(d, "d MMM");
    }
    function daysLabel(n) { return n === 0 ? "today" : n === 1 ? "tomorrow" : `${n} days`; }

    // ── what fits ────────────────────────────────────────────────────────
    // heights measured in this rice's type, so the plan holds in every rice
    readonly property real lineH: probe.implicitHeight
    readonly property real headH: probeHead.implicitHeight + 4
    readonly property real smallH: probeSmall.implicitHeight
    readonly property real taskRow: Math.max(DeskTheme.textSize + 4, lineH) + 6 + 4
    readonly property real countRow: lineH + 6 + 4
    readonly property real briefLine: probeBrief.implicitHeight
    readonly property real gap: 12

    readonly property bool fixedH: card.liveH > 0 || DeskState.cardSize.height > 0
    readonly property bool wide: card.width >= 620

    readonly property var plan: {
        const nT = DeskState.today.length, nC = DeskState.countdowns.length;
        const head = title.implicitHeight;
        if (!fixedH) return { compact: false, t: Math.min(nT, 6), c: Math.min(nC, 4), b: 3, footer: true };
        let a = card.height - 36 - head - gap;
        const more = smallH + 4;
        const todayRows = (room, reserve) => {
            let t = Math.min(nT, Math.floor((room - reserve - headH) / taskRow));
            if (t < nT) t = Math.min(nT, Math.floor((room - reserve - headH - more) / taskRow));
            return Math.max(0, t);
        };
        const used = t => headH + Math.max(t, nT ? 0 : 1) * taskRow + (t < nT ? more : 0);
        if (a < headH + taskRow) return { compact: true, t: 0, c: 0, b: 0, footer: false };
        let t, c = 0, b = 0, rest;
        if (wide) {
            t = Math.max(nT ? 1 : 0, todayRows(a, 0));
            rest = a;
        } else {
            const reserve = nC ? gap + headH + Math.min(nC, 2) * countRow : 0;
            t = Math.max(nT ? 1 : 0, todayRows(a, reserve));
            rest = a - used(t) - gap;
        }
        if (rest >= headH + countRow) {
            c = Math.min(Math.max(nC, 1), Math.floor((rest - headH) / countRow));
            rest -= headH + c * countRow + gap;
        }
        if (rest >= headH + 4 + briefLine) {
            b = Math.min(12, Math.floor((rest - headH - 4) / briefLine));
            rest -= headH + 4 + b * briefLine + gap;
        }
        return { compact: false, t: t, c: Math.min(c, nC), cShown: c > 0, b: b, footer: rest >= smallH || DeskState.error !== "" };
    }
    readonly property var tasks: DeskState.today.slice(0, plan.t)
    readonly property var counts: DeskState.countdowns.slice(0, plan.c)
    // the brief's first lines that aren't headings
    readonly property string briefText: (DeskState.brief.blocks ?? [])
        .filter(b => b.text && !/^h\d$/.test(b.kind)).slice(0, 12).map(b => b.text).join("\n")
    readonly property string summary: {
        const n = DeskState.countdowns[0];
        return [DeskState.open ? `${DeskState.open} open` : "Nothing on today",
                n ? `${n.event} in ${daysLabel(n.days)}`.replace(" in today", " today").replace(" in tomorrow", " tomorrow") : ""]
               .filter(s => s).join("  ·  ");
    }

    DeskText { id: probe; visible: false; text: "Ag" }
    DeskText { id: probeHead; visible: false; text: "AG"; scale: 0.74; strong: true }
    DeskText { id: probeSmall; visible: false; text: "Ag"; scale: 0.8 }
    DeskText { id: probeBrief; visible: false; text: "Ag"; scale: 0.92 }

    component Heading: Item {
        id: head
        property string label: ""
        property string detail: ""
        width: parent.width
        height: t.implicitHeight + 4
        DeskText {
            id: t
            y: 2
            text: head.label.toUpperCase()
            strong: true
            muted: true
            scale: 0.74
            font.letterSpacing: 1.4
        }
        DeskText {
            anchors.right: parent.right
            anchors.verticalCenter: t.verticalCenter
            text: head.detail
            muted: true
            scale: 0.78
        }
    }

    // a dot on an edge: drag it to move that edge
    component Handle: Rectangle {
        id: h
        property int dx: 0          // -1 the left edge, 1 the right, 0 neither
        property int dy: 0          // -1 the top edge, 1 the bottom
        width: 18
        height: 18
        radius: 9
        color: DeskTheme.accent
        border.color: DeskTheme.onAccent
        border.width: 2
        visible: win.resizing
        x: (dx < 0 ? 0 : dx > 0 ? card.width : card.width / 2) - width / 2
        y: (dy < 0 ? 0 : dy > 0 ? card.height : card.height / 2) - height / 2
        scale: hd.active ? 1.25 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        HoverHandler { cursorShape: h.dx !== 0 ? Qt.SizeHorCursor : Qt.SizeVerCursor }
        DragHandler {
            id: hd
            target: null
            property real w0: 0
            property real h0: 0
            property real x0: 0
            property real y0: 0
            onActiveChanged: {
                if (active) {
                    w0 = card.width; h0 = card.height; x0 = card.x; y0 = card.y;
                    card.x = x0; card.y = y0;                       // hold the place while it changes
                    card.liveW = w0;
                    if (h.dy !== 0) card.liveH = h0;
                } else {
                    card.settle();
                }
            }
            onTranslationChanged: {
                if (!active) return;
                if (h.dx !== 0) {
                    const room = h.dx > 0 ? win.width - x0 : x0 + w0;
                    const w = Math.max(win.minW, Math.min(win.maxW, room, w0 + h.dx * translation.x));
                    card.liveW = w;
                    if (h.dx < 0) card.x = x0 + w0 - w;
                }
                if (h.dy !== 0) {
                    const room = h.dy > 0 ? win.height - y0 : y0 + h0;
                    const hh = Math.max(win.minH, Math.min(win.maxH, room, h0 + h.dy * translation.y));
                    card.liveH = hh;
                    if (h.dy < 0) card.y = y0 + h0 - hh;
                }
            }
        }
    }

    // the rest of the screen, while resizing: a click there ends it
    MouseArea {
        id: cover
        anchors.fill: parent
        enabled: win.resizing
        onClicked: DeskState.cardResizing = false
    }

    Item {
        id: card

        // a size being dragged, until it's saved
        property real liveW: 0
        property real liveH: 0
        width: liveW > 0 ? liveW : Math.max(win.minW, Math.min(win.maxW, DeskState.cardSize.width))
        height: liveH > 0 ? liveH
              : DeskState.cardSize.height > 0 ? Math.max(win.minH, Math.min(win.maxH, DeskState.cardSize.height))
              : col.implicitHeight + 36

        x: DeskState.cardAt.x * (win.width - width)
        y: DeskState.cardAt.y * (win.height - height)
        scale: drag.active && !DeskTheme.reducedMotion ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: DeskTheme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: DeskTheme.curveIn } }

        // where it is and how big, kept; then back to following what's kept
        function settle() {
            DeskState.setCardSize(card.width, card.liveH > 0 || DeskState.cardSize.height > 0 ? card.height : 0);
            DeskState.setCardAt(card.x / Math.max(1, win.width - card.width),
                                card.y / Math.max(1, win.height - card.height));
            card.liveW = 0;
            card.liveH = 0;
            card.x = Qt.binding(() => DeskState.cardAt.x * (win.width - card.width));
            card.y = Qt.binding(() => DeskState.cardAt.y * (win.height - card.height));
        }

        DragHandler {
            id: drag
            cursorShape: Qt.ClosedHandCursor
            xAxis.minimum: 0; xAxis.maximum: win.width - card.width
            yAxis.minimum: 0; yAxis.maximum: win.height - card.height
            onActiveChanged: if (!active) card.settle()
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: { DeskState.cardResizing = false; DeskState.setCardShown(false); }
        }
        // hold it: Android's resize
        TapHandler {
            longPressThreshold: 0.5
            onLongPressed: DeskState.cardResizing = true
        }

        Loader {
            anchors.fill: parent
            sourceComponent: DeskTheme.cardBackdrop ?? DeskTheme.backdrop ?? solid
            onLoaded: {
                if ("screen" in item) item.screen = Qt.binding(() => win.screen);
                if ("windowOrigin" in item) item.windowOrigin = Qt.binding(() => Qt.point(card.x, card.y));
                if ("opened" in item) item.opened = true;
            }
        }
        Component {
            id: solid
            Rectangle {
                radius: DeskTheme.radius
                color: DeskTheme.surface
                border.color: DeskTheme.line
            }
        }

        Item {
            anchors.fill: parent
            clip: win.fixedH

            Column {
                id: col
                x: 20
                y: 18
                width: card.width - 40
                spacing: win.gap

                // Desk · Synced 2m ago
                Item {
                    width: parent.width
                    height: title.implicitHeight
                    DeskGlyph {
                        id: glyph
                        anchors.verticalCenter: parent.verticalCenter
                        size: DeskTheme.textSize + 4
                    }
                    DeskText {
                        id: title
                        anchors.left: glyph.right
                        anchors.leftMargin: 10
                        text: "Desk"
                        font.family: DeskTheme.fontDisplay
                        strong: true
                        scale: 1.3
                        TapHandler { onTapped: win.open() }
                    }
                    DeskText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !win.resizing
                        text: DeskState.syncing ? "Syncing…" : DeskState.badge !== "" ? DeskState.badge : DeskState.syncedLabel
                        color: DeskState.badge !== "" ? DeskTheme.warn : DeskTheme.textMuted
                        scale: 0.8
                        TapHandler { onTapped: DeskState.syncNow() }
                    }
                    DeskChip {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: win.resizing
                        small: true
                        on: true
                        label: "Done"
                        onClicked: DeskState.cardResizing = false
                    }
                }

                // small: one line
                DeskText {
                    width: parent.width
                    visible: win.plan.compact
                    text: DeskState.loaded ? win.summary : "Waiting for the first sync"
                    muted: !DeskState.loaded
                    TapHandler { onTapped: win.open() }
                }

                Grid {
                    id: body
                    visible: !win.plan.compact
                    width: parent.width
                    columns: win.wide ? 2 : 1
                    columnSpacing: 24
                    rowSpacing: win.gap
                    readonly property real colW: win.wide ? (width - columnSpacing) / 2 : width

                    // Today
                    Column {
                        width: body.colW
                        spacing: 4
                        Heading {
                            label: "Today"
                            detail: DeskState.open === 0 ? "" : DeskState.overdue > 0
                                    ? `${DeskState.open} open · ${DeskState.overdue} overdue` : `${DeskState.open} open`
                        }
                        DeskText {
                            visible: DeskState.today.length === 0
                            text: DeskState.loaded ? "Nothing on today" : "Waiting for the first sync"
                            muted: true
                        }
                        Repeater {
                            model: win.tasks
                            delegate: Item {
                                id: task
                                required property var modelData
                                readonly property var t: modelData
                                width: parent.width
                                height: Math.max(box.height, name.implicitHeight) + 6
                                opacity: t.done ? 0.5 : 1

                                DeskCheck {
                                    id: box
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: task.t.done
                                    busy: task.t.pending === true
                                    TapHandler { onTapped: if (!win.resizing) DeskState.toggle(task.t.id) }
                                }
                                DeskText {
                                    id: name
                                    anchors.left: box.right
                                    anchors.leftMargin: 10
                                    anchors.right: meta.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: task.t.title
                                    font.strikeout: task.t.done
                                }
                                DeskText {
                                    id: meta
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: [task.t.area, win.when(task.t)].filter(s => s).join(" · ")
                                    color: task.t.state === "overdue" && !task.t.done ? DeskTheme.danger
                                         : task.t.state === "today" && !task.t.done ? DeskTheme.warn : DeskTheme.textMuted
                                    scale: 0.8
                                }
                                // the box ticks; the rest of the row opens the task
                                Item {
                                    anchors.left: box.right
                                    anchors.right: parent.right
                                    height: parent.height
                                    TapHandler { onTapped: win.open("today", task.t.id) }
                                }
                            }
                        }
                        DeskText {
                            visible: DeskState.today.length > win.tasks.length
                            text: `+${DeskState.today.length - win.tasks.length} more`
                            muted: true
                            scale: 0.8
                            TapHandler { onTapped: win.open("today") }
                        }
                    }

                    // Countdowns, then the brief
                    Column {
                        width: body.colW
                        spacing: win.gap

                        Column {
                            width: parent.width
                            spacing: 4
                            visible: win.fixedH ? win.plan.cShown === true : (win.counts.length > 0 || DeskState.loaded)
                            Heading { label: "Countdowns" }
                            DeskText {
                                visible: win.counts.length === 0
                                text: "Nothing counting down"
                                muted: true
                            }
                            Repeater {
                                model: win.counts
                                delegate: Item {
                                    id: cd
                                    required property var modelData
                                    readonly property var c: modelData
                                    width: parent.width
                                    height: ev.implicitHeight + 6
                                    DeskText {
                                        id: ev
                                        anchors.left: parent.left
                                        anchors.right: days.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: cd.c.event
                                    }
                                    DeskText {
                                        id: days
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: win.daysLabel(cd.c.days)
                                        font.family: DeskTheme.fontMono
                                        strong: cd.c.soon
                                        color: cd.c.soon ? DeskTheme.warn : DeskTheme.text
                                        scale: 0.9
                                    }
                                    TapHandler { onTapped: win.open("countdowns", cd.c.id) }
                                }
                            }
                        }

                        // the brief's first lines
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: win.plan.b > 0
                            Heading { label: "Brief" }
                            DeskText {
                                width: parent.width
                                text: win.briefText || (DeskState.loaded ? "Nothing in the brief yet" : "Waiting for the first sync")
                                muted: win.briefText === ""
                                wrapMode: Text.Wrap
                                maximumLineCount: Math.max(1, win.plan.b)
                                scale: 0.92
                            }
                            TapHandler { onTapped: win.open("brief") }
                        }
                    }
                }

                DeskText {
                    width: parent.width
                    visible: win.plan.footer
                    text: DeskState.error !== "" ? DeskState.error
                        : win.resizing ? "Drag a dot to resize · click outside when done"
                        : "Click to open all of Notion's Desk · hold to resize"
                    color: DeskState.error !== "" ? DeskTheme.danger : DeskTheme.textMuted
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    scale: 0.78
                    TapHandler { onTapped: win.open() }
                }
            }
        }

        // resizing: an outline and a dot on each edge
        Rectangle {
            anchors.fill: parent
            visible: win.resizing
            color: "transparent"
            radius: DeskTheme.radius
            border.color: DeskTheme.accent
            border.width: 2
        }
        Handle { dx: -1 }
        Handle { dx: 1 }
        Handle { dy: -1 }
        Handle { dy: 1 }
    }
}
