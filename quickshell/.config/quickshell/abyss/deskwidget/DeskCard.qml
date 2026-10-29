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
PanelWindow {
    id: win

    property bool hidden: false
    readonly property int maxTasks: 6
    readonly property int maxCountdowns: 4

    screen: Quickshell.screens[0] ?? null
    visible: DeskState.cardShown && !hidden && !DeskState.viewOpen

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: DeskTheme.cardNamespace

    mask: Region { item: card }

    function open(what, id) { DeskState.openView(win.screen?.name ?? "", what, id); }

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

    readonly property var tasks: DeskState.today.slice(0, maxTasks)
    readonly property var counts: DeskState.countdowns.slice(0, maxCountdowns)
    // the brief's first lines that aren't headings
    readonly property string briefText: (DeskState.brief.blocks ?? [])
        .filter(b => b.text && !/^h\d$/.test(b.kind)).slice(0, 3).map(b => b.text).join("\n")

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

    Item {
        id: card
        width: 360
        height: col.implicitHeight + 36

        x: DeskState.cardAt.x * (win.width - width)
        y: DeskState.cardAt.y * (win.height - height)
        scale: drag.active && !DeskTheme.reducedMotion ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: DeskTheme.durIn; easing.type: Easing.BezierSpline; easing.bezierCurve: DeskTheme.curveIn } }

        DragHandler {
            id: drag
            cursorShape: Qt.ClosedHandCursor
            xAxis.minimum: 0; xAxis.maximum: win.width - card.width
            yAxis.minimum: 0; yAxis.maximum: win.height - card.height
            onActiveChanged: if (!active) {
                DeskState.setCardAt(card.x / Math.max(1, win.width - card.width),
                                    card.y / Math.max(1, win.height - card.height));
                card.x = Qt.binding(() => DeskState.cardAt.x * (win.width - card.width));
                card.y = Qt.binding(() => DeskState.cardAt.y * (win.height - card.height));
            }
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: DeskState.setCardShown(false)
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

        Column {
            id: col
            x: 20
            y: 18
            width: card.width - 40
            spacing: 12

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
                    text: DeskState.syncing ? "Syncing…" : DeskState.badge !== "" ? DeskState.badge : DeskState.syncedLabel
                    color: DeskState.badge !== "" ? DeskTheme.warn : DeskTheme.textMuted
                    scale: 0.8
                    TapHandler { onTapped: DeskState.syncNow() }
                }
            }

            // Today
            Column {
                width: parent.width
                spacing: 4
                Heading {
                    label: "Today"
                    detail: DeskState.open === 0 ? "" : DeskState.overdue > 0
                            ? `${DeskState.open} open · ${DeskState.overdue} overdue` : `${DeskState.open} open`
                }
                DeskText {
                    visible: win.tasks.length === 0
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
                            TapHandler { onTapped: DeskState.toggle(task.t.id) }
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
                }
            }

            // Countdowns
            Column {
                width: parent.width
                spacing: 4
                visible: win.counts.length > 0 || DeskState.loaded
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
                Heading { label: "Brief" }
                DeskText {
                    width: parent.width
                    text: win.briefText || (DeskState.loaded ? "Nothing in the brief yet" : "Waiting for the first sync")
                    muted: win.briefText === ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    scale: 0.92
                }
                TapHandler { onTapped: win.open("brief") }
            }

            DeskText {
                width: parent.width
                text: DeskState.error !== "" ? DeskState.error : "Click to open all of Notion's Desk"
                color: DeskState.error !== "" ? DeskTheme.danger : DeskTheme.textMuted
                wrapMode: Text.Wrap
                maximumLineCount: 2
                scale: 0.78
                TapHandler { onTapped: win.open() }
            }
        }
    }
}
