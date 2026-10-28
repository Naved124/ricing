pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The whole Notion widget, over everything, dressed in the active rice like
// the network widget: opened from the desk card (↗ or its title), the control
// centre's Notion tile (right-click) or `qs -c rice ipc call notion open`.
//   Tasks    filter (open, today, overdue, someday), tick, step the status,
//            add one with a due date
//   Agenda   today and the days ahead, by day
//   Pinned   the pinned page's to-dos, under their headings
//   Recent   the pages last edited
//   Capture  a note for the inbox (first line the title; Ctrl+Return sends)
// Keys: 1–5 the tabs, R refresh, N a new task, Esc closes. A click on any
// title opens it in Notion.
PanelWindow {
    id: win

    readonly property var tabs: [
        { id: "tasks", name: "Tasks" }, { id: "agenda", name: "Agenda" }, { id: "pinned", name: "Pinned" },
        { id: "recent", name: "Recent" }, { id: "capture", name: "Capture" }
    ]
    property real now: Date.now()
    property string due: ""             // the new task's due date

    screen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }
    visible: Notion.panelOpen || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-notion-panel"
    WlrLayershell.keyboardFocus: Notion.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: Notion
        function onPanelOpenChanged() {
            if (!Notion.panelOpen) return;
            win.now = Date.now();
            keys.forceActiveFocus();
        }
    }
    Timer { interval: 30000; repeat: true; running: Notion.panelOpen; onTriggered: win.now = Date.now() }

    function close() { Notion.panelOpen = false; }
    function addTask() {
        Notion.add(newTask.text, win.due);
        newTask.text = "";
    }
    // the agenda by day: [{ day, items }]
    readonly property var days: {
        const out = [];
        for (const a of Notion.agenda) {
            const last = out[out.length - 1];
            if (last && last.day === a.day) last.items.push(a);
            else out.push({ day: a.day, items: [a] });
        }
        return out;
    }
    function ago(iso) {
        const s = Math.max(0, (win.now - new Date(iso).getTime()) / 1000);
        return s < 60 ? "just now" : s < 3600 ? `${Math.floor(s / 60)} min` : s < 86400 ? `${Math.floor(s / 3600)} h`
             : `${Math.floor(s / 86400)} d`;
    }

    Rectangle {
        id: veil
        anchors.fill: parent
        color: Qt.alpha(NotionLook.role("bg"), 0.45)
        opacity: Notion.panelOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Notion.panelOpen ? 280 : 200; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: win.close() }
    }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: win.close()
        Keys.onPressed: event => {
            const i = event.key - Qt.Key_1;
            if (i >= 0 && i < win.tabs.length) { Notion.setTab(win.tabs[i].id); event.accepted = true; }
            else if (event.key === Qt.Key_R) { Notion.refresh(); event.accepted = true; }
            else if (event.key === Qt.Key_N) { Notion.setTab("tasks"); newTask.focusIn(); event.accepted = true; }
        }
    }

    component Heading: NotionText {
        size: NotionLook.uiSize - 3
        bold: true
        dim: true
        font.letterSpacing: 1.4
        font.capitalization: Font.AllUppercase
    }
    component Button: Rectangle {
        id: b
        property string text: ""
        property bool primary: false
        signal clicked()
        implicitWidth: bt.implicitWidth + 24
        implicitHeight: 32
        radius: NotionLook.chip
        color: primary ? NotionLook.role("accent") : Qt.alpha(NotionLook.role("fg"), bm.containsMouse ? 0.12 : 0.06)
        opacity: enabled ? 1 : 0.5
        NotionText {
            id: bt
            anchors.centerIn: parent
            text: b.text
            size: NotionLook.uiSize - 1.5
            bold: true
            color: b.primary ? NotionLook.on(NotionLook.role("accent")) : NotionLook.role("fg")
        }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
    component Empty: NotionText {
        width: parent.width
        height: 60
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        dim: true
        size: NotionLook.uiSize - 1
    }

    // ── the sheet ───────────────────────────────────────────────────────────
    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 600)
        height: Math.min(parent.height - 120, 640)
        radius: NotionLook.radius
        color: NotionLook.role("surface")
        border.width: 1
        border.color: NotionLook.role("border")
        opacity: veil.opacity
        scale: Notion.panelOpen ? 1 : 0.97
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

        // ── header ────────────────────────────────────────────────────────
        Item {
            id: header
            x: 22; y: 18
            width: parent.width - 44
            height: 38
            Rectangle {
                id: mark
                width: 34; height: 34
                anchors.verticalCenter: parent.verticalCenter
                radius: NotionLook.chip
                color: NotionLook.role("fg")
                NotionText { anchors.centerIn: parent; text: "N"; font.family: NotionLook.fontDisplay; size: 21; bold: true; color: NotionLook.role("bg") }
            }
            Column {
                anchors.left: mark.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                NotionText { text: "Notion"; font.family: NotionLook.fontDisplay; size: NotionLook.uiSize + 7; bold: true }
                NotionText {
                    text: Notion.setup ? "not set up" : Notion.busy ? "syncing…"
                        : !Notion.ok ? "offline · last read " + Notion.ago(win.now) : "synced " + Notion.ago(win.now)
                    size: NotionLook.uiSize - 2.5
                    color: !Notion.ok ? NotionLook.role("urgent") : NotionLook.role("muted")
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Button { text: Notion.busy ? "Syncing…" : "Refresh"; onClicked: Notion.refresh() }
                Button { text: "Close"; onClicked: win.close() }
            }
        }

        // ── tabs ──────────────────────────────────────────────────────────
        Row {
            id: tabRow
            anchors.top: header.bottom
            anchors.topMargin: 16
            x: 22
            spacing: 4
            Repeater {
                model: win.tabs
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool lit: Notion.tab === modelData.id
                    readonly property int count: modelData.id === "tasks" ? Notion.tasks.length
                                               : modelData.id === "agenda" ? Notion.agenda.length
                                               : modelData.id === "pinned" ? Notion.pinned.items.filter(t => !Notion.ticked(t)).length : 0
                    width: tl.implicitWidth + 26
                    height: 32
                    radius: NotionLook.chip
                    color: lit ? NotionLook.role("selection") : Qt.alpha(NotionLook.role("fg"), tm.containsMouse ? 0.07 : 0)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    NotionText {
                        id: tl
                        anchors.centerIn: parent
                        text: tab.modelData.name + (tab.count ? `  ${tab.count}` : "")
                        size: NotionLook.uiSize - 1
                        bold: tab.lit
                        dim: !tab.lit
                    }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notion.setTab(tab.modelData.id) }
                }
            }
        }
        Rectangle {
            id: rule
            anchors.top: tabRow.bottom
            anchors.topMargin: 12
            x: 22
            width: parent.width - 44
            height: 1
            color: NotionLook.role("border")
        }

        NotionText {
            id: err
            visible: !!Notion.error
            anchors.top: rule.bottom
            anchors.topMargin: 10
            x: 22
            width: parent.width - 44
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            maximumLineCount: 3
            text: Notion.error
            color: NotionLook.role("urgent")
            size: NotionLook.uiSize - 2
        }

        // ── the pages ─────────────────────────────────────────────────────
        Item {
            id: pages
            anchors.top: err.visible ? err.bottom : rule.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            x: 22
            width: parent.width - 44

            // Tasks
            Item {
                anchors.fill: parent
                visible: Notion.tab === "tasks"
                Column {
                    id: taskTop
                    width: parent.width
                    spacing: 10
                    Row {
                        spacing: 6
                        Repeater {
                            model: [["open", "Open"], ["today", "Today"], ["overdue", "Overdue"], ["someday", "No date"]]
                            delegate: NotionChip {
                                required property var modelData
                                text: `${modelData[1]}  ${Notion.filtered(modelData[0]).length}`
                                tone: modelData[0] === "overdue" ? "urgent" : "accent"
                                lit: Notion.filter === modelData[0]
                                clickable: true
                                implicitHeight: 26
                                onClicked: Notion.setFilter(modelData[0])
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 6
                        NotionField {
                            id: newTask
                            width: parent.width - dueRow.width - addBtn.width - 12
                            placeholder: "New task"
                            onAccepted: win.addTask()
                            onEscaped: keys.forceActiveFocus()
                        }
                        Row {
                            id: dueRow
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: [["", "No date"], ["today", "Today"], ["tomorrow", "Tomorrow"], ["+7", "Next week"]]
                                delegate: NotionChip {
                                    required property var modelData
                                    text: modelData[1]
                                    tone: "accent"
                                    lit: win.due === modelData[0]
                                    clickable: true
                                    implicitHeight: 26
                                    onClicked: win.due = modelData[0]
                                }
                            }
                        }
                        Button { id: addBtn; text: "Add"; primary: true; enabled: !!newTask.text.trim(); onClicked: win.addTask() }
                    }
                }
                ListView {
                    anchors.top: taskTop.bottom
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    width: parent.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Notion.filtered(Notion.filter)
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: NotionTask {
                        required property var modelData
                        width: ListView.view.width - 10
                        task: modelData
                    }
                    add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
                    Empty {
                        visible: parent.count === 0
                        y: 30
                        text: !Notion.configured ? "Set [tasks] database in ~/.config/rice/notion.toml."
                            : Notion.filter === "overdue" ? "Nothing overdue." : Notion.filter === "today" ? "Nothing due today."
                            : "Nothing here."
                    }
                }
            }

            // Agenda
            Flickable {
                anchors.fill: parent
                visible: Notion.tab === "agenda"
                contentHeight: agendaCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Column {
                    id: agendaCol
                    width: parent.width - 10
                    spacing: 14
                    Empty { visible: !win.days.length; text: "Nothing on the agenda this week." }
                    Repeater {
                        model: win.days
                        delegate: Column {
                            id: dayCol
                            required property var modelData
                            width: agendaCol.width
                            spacing: 4
                            Heading { text: Notion.dayName(dayCol.modelData.day) + "  ·  " + new Date(dayCol.modelData.day + "T00:00:00").toLocaleDateString(Qt.locale(), "d MMMM") }
                            Repeater {
                                model: dayCol.modelData.items
                                delegate: Rectangle {
                                    id: ev
                                    required property var modelData
                                    width: dayCol.width
                                    height: 40
                                    radius: NotionLook.chip
                                    color: Qt.alpha(NotionLook.role("accent"), em.containsMouse ? 0.16 : 0.08)
                                    Rectangle { width: 3; height: parent.height - 14; anchors.verticalCenter: parent.verticalCenter; radius: 1.5; color: NotionLook.role("accent") }
                                    NotionText {
                                        id: evTime
                                        x: 14
                                        width: 92
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: ev.modelData.allDay ? "all day"
                                            : Notion.timeOf(ev.modelData.start) + (ev.modelData.end ? "–" + Notion.timeOf(ev.modelData.end) : "")
                                        font.family: NotionLook.fontMono
                                        size: NotionLook.uiSize - 2.5
                                        dim: true
                                    }
                                    NotionText {
                                        anchors.left: evTime.right
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (ev.modelData.icon ? ev.modelData.icon + "  " : "") + ev.modelData.title
                                        bold: true
                                        size: NotionLook.uiSize - 1
                                    }
                                    MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notion.open(ev.modelData.url) }
                                }
                            }
                        }
                    }
                }
            }

            // Pinned
            Flickable {
                anchors.fill: parent
                visible: Notion.tab === "pinned"
                contentHeight: pinCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Column {
                    id: pinCol
                    width: parent.width - 10
                    spacing: 2
                    Empty { visible: !Notion.pinned.configured; text: "Pin a page: set [pinned] page in ~/.config/rice/notion.toml." }
                    NotionText {
                        visible: Notion.pinned.configured
                        width: parent.width
                        height: 34
                        text: (Notion.pinned.icon ? Notion.pinned.icon + "  " : "") + Notion.pinned.title + "  ↗"
                        font.family: NotionLook.fontDisplay
                        size: NotionLook.uiSize + 3
                        bold: true
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notion.open(Notion.pinned.url) }
                    }
                    // how far through it is
                    Rectangle {
                        visible: Notion.pinned.items.length > 0
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.alpha(NotionLook.role("fg"), 0.1)
                        Rectangle {
                            height: parent.height
                            radius: 2
                            color: NotionLook.role("success")
                            width: parent.width * Notion.pinned.items.filter(t => Notion.ticked(t)).length / Math.max(1, Notion.pinned.items.length)
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                    Item { width: 1; height: 8 }
                    Empty { visible: Notion.pinned.configured && !Notion.pinned.items.length; text: "No to-dos on this page." }
                    Repeater {
                        model: Notion.pinned.items
                        delegate: Column {
                            id: todo
                            required property var modelData
                            required property int index
                            readonly property bool ticked: Notion.ticked(modelData)
                            width: pinCol.width
                            Heading {
                                visible: !!todo.modelData.group && (todo.index === 0 || Notion.pinned.items[todo.index - 1].group !== todo.modelData.group)
                                text: todo.modelData.group
                                topPadding: 10
                                bottomPadding: 4
                            }
                            Item {
                                width: parent.width
                                height: 32
                                NotionCheck {
                                    id: tt
                                    anchors.verticalCenter: parent.verticalCenter
                                    on: todo.ticked
                                    onToggled: Notion.setTodo(todo.modelData.id, !todo.ticked)
                                }
                                NotionText {
                                    anchors.left: tt.right
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: todo.modelData.text
                                    font.strikeout: todo.ticked
                                    dim: todo.ticked
                                }
                            }
                        }
                    }
                }
            }

            // Recent
            ListView {
                anchors.fill: parent
                visible: Notion.tab === "recent"
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: Notion.recent
                delegate: Rectangle {
                    id: page
                    required property var modelData
                    width: ListView.view.width
                    height: 44
                    radius: NotionLook.chip
                    color: Qt.alpha(NotionLook.role("fg"), pm.containsMouse ? 0.07 : 0)
                    Rectangle {
                        id: glyph
                        x: 8
                        width: 28; height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        radius: NotionLook.chip - 2
                        color: Qt.alpha(NotionLook.role("fg"), 0.07)
                        NotionText {
                            anchors.centerIn: parent
                            text: page.modelData.icon || (page.modelData.kind === "database" ? "▦" : "▤")
                            size: NotionLook.uiSize
                            dim: !page.modelData.icon
                        }
                    }
                    NotionText {
                        anchors.left: glyph.right
                        anchors.leftMargin: 12
                        anchors.right: when.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.modelData.title
                        bold: true
                        size: NotionLook.uiSize - 0.5
                    }
                    NotionText {
                        id: when
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.ago(page.modelData.edited)
                        dim: true
                        size: NotionLook.uiSize - 2.5
                    }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notion.open(page.modelData.url) }
                }
                Empty { visible: parent.count === 0; y: 30; text: "Share pages with the integration and they show here." }
            }

            // Capture
            Column {
                anchors.fill: parent
                visible: Notion.tab === "capture"
                spacing: 10
                NotionText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    dim: true
                    size: NotionLook.uiSize - 1.5
                    text: Notion.canCapture ? "The first line is the title, the rest its text. Ctrl+Return sends it to the inbox."
                                            : "Set [inbox] database (or [tasks]) in ~/.config/rice/notion.toml."
                }
                Rectangle {
                    width: parent.width
                    height: Math.max(160, parent.height - 110)
                    radius: NotionLook.chip
                    color: Qt.alpha(NotionLook.role("fg"), 0.05)
                    border.width: 1
                    border.color: note.activeFocus ? NotionLook.role("accent") : Qt.alpha(NotionLook.role("fg"), 0.12)
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 4
                        TextArea {
                            id: note
                            background: null
                            wrapMode: TextEdit.Wrap
                            placeholderText: "A thought, a link, a list…"
                            color: NotionLook.role("fg")
                            placeholderTextColor: NotionLook.role("muted")
                            selectionColor: Qt.alpha(NotionLook.role("accent"), 0.35)
                            selectedTextColor: NotionLook.role("fg")
                            font.family: NotionLook.fontUi
                            font.pixelSize: NotionLook.uiSize
                            Keys.onEscapePressed: keys.forceActiveFocus()
                            Keys.onPressed: event => {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                                    send.clicked();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    NotionText { height: 32; text: note.text.length ? `${note.text.length} characters` : ""; dim: true; size: NotionLook.uiSize - 2.5 }
                    Button {
                        id: send
                        text: "Send to inbox"
                        primary: true
                        enabled: Notion.canCapture && !!note.text.trim()
                        onClicked: if (enabled) { Notion.capture(note.text); note.text = ""; }
                    }
                }
            }
        }
    }
}
