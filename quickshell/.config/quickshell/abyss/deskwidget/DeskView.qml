pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// The full view: all of Notion's Desk, so the website isn't needed. Every
// database and page on the Desk page down the left (in config.toml's [view]
// order), the chosen one's rows in the middle (search, finished ones hidden
// or not, + New), and the chosen row on the right, every property editable
// the way its type is (DeskField), with Open in Notion and Move to trash.
// The brief and the weekly reviews are read here, not edited. Edits show at
// once and go through desk-sync; one it refuses comes back with the reason.
// Esc closes it (or drops a new row's draft); Ctrl+N starts one, Ctrl+F
// searches. One per screen; it opens on the one asked for.
PanelWindow {
    id: win

    required property var modelData
    readonly property bool open: DeskState.viewOpen
                                 && (DeskState.viewScreen === "" || DeskState.viewScreen === modelData.name)

    // what's chosen on the left: a database or a page
    readonly property string name: DeskState.order.indexOf(DeskState.source) >= 0 ? DeskState.source
                                                                                 : (DeskState.order[0] ?? "today")
    readonly property bool isPage: !(name in DeskState.sources) && name in DeskState.pages
    readonly property var src: DeskState.sources[name] ?? null
    readonly property var schema: src?.schema ?? []
    readonly property string titleProp: DeskState.titleField(src)
    readonly property string query: searchBox.typed.trim().toLowerCase()
    readonly property var rows: (src?.rows ?? []).filter(r => (!DeskState.hideFinished || !r.closed || r.id === DeskState.selected)
                                                            && matches(r))
    readonly property int finished: (src?.rows ?? []).filter(r => r.closed).length

    // the row on the right, or the new row's draft
    readonly property bool drafting: DeskState.selected === "new"
    readonly property var sel: drafting ? null : DeskState.row(name, DeskState.selected)
    property var draft: ({})
    property bool confirmTrash: false

    screen: modelData
    visible: open || pane.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: DeskTheme.namespace
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) keys.forceActiveFocus()
    onNameChanged: { searchBox.text = ""; searchBox.show(); draft = ({}); }
    onSelChanged: confirmTrash = false

    function matches(r) {
        if (query === "") return true;
        for (const f of schema) {
            if (DeskState.show(f, r.v[f.name]).toLowerCase().indexOf(query) >= 0) return true;
        }
        return false;
    }
    // a row's second line: its first few short values that aren't empty
    function summary(r) {
        const out = [];
        for (const f of schema) {
            if (f.name === titleProp || f.name === src.done || out.length >= 4) continue;
            const v = r.v[f.name];
            if (f.type === "checkbox") { if (v === true) out.push(f.name); continue; }
            if (["select", "status", "multi_select", "date", "number"].indexOf(f.type) < 0) continue;
            const s = DeskState.show(f, v);
            if (s !== "") out.push(s);
        }
        return out.join("  ·  ");
    }
    function label(n) {
        return DeskState.sources[n]?.title ?? DeskState.pages[n]?.title ?? n;
    }
    function count(n) {
        if (n in DeskState.sources) return DeskState.sources[n].rows.filter(r => !r.closed).length;
        const p = DeskState.pages[n];
        return p?.pages?.length ?? 0;
    }
    function startDraft() {
        if (!src) return;
        draft = ({});
        DeskState.selected = "new";
    }
    function addDraft() {
        const values = {};
        for (const k of Object.keys(draft)) {
            const v = draft[k];
            if (v === null || v === "" || (Array.isArray(v) && !v.length)) continue;
            values[k] = v;
        }
        if (!values[titleProp]) { DeskState.say(`give it a ${titleProp} first`); return; }
        const key = DeskState.add(name, values);
        if (key) { draft = ({}); DeskState.selected = key; }
    }
    function close() {
        if (drafting) { DeskState.selected = ""; return; }
        DeskState.viewOpen = false;
    }

    // a click outside the pane closes it
    MouseArea {
        anchors.fill: parent
        onClicked: DeskState.viewOpen = false
    }

    Item {
        id: pane
        width: Math.min(1240, win.width - DeskTheme.gap * 2 - 40)
        height: Math.min(860, win.height - DeskTheme.barHeight - DeskTheme.gap * 3)
        x: (win.width - width) / 2
        y: Math.max(DeskTheme.barHeight + DeskTheme.gap, (win.height - height) / 2)

        readonly property int dur: win.open ? DeskTheme.durIn : DeskTheme.durOut
        readonly property var curve: win.open ? DeskTheme.curveIn : DeskTheme.curveOut
        opacity: win.open ? 1 : 0
        scale: win.open || DeskTheme.reducedMotion ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: pane.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: pane.curve } }
        Behavior on scale { NumberAnimation { duration: pane.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: pane.curve } }

        MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

        Loader {
            anchors.fill: parent
            sourceComponent: DeskTheme.backdrop ?? solid
            onLoaded: {
                if ("screen" in item) item.screen = Qt.binding(() => win.screen);
                if ("windowOrigin" in item) item.windowOrigin = Qt.binding(() => Qt.point(pane.x, pane.y));
                if ("opened" in item) item.opened = Qt.binding(() => win.open);
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

        // the keys, whatever box doesn't have the focus
        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: win.close()
            Keys.onPressed: event => {
                if (!(event.modifiers & Qt.ControlModifier)) return;
                if (event.key === Qt.Key_N && !win.isPage) { win.startDraft(); event.accepted = true; }
                if (event.key === Qt.Key_F && !win.isPage) { searchBox.focusIn(); event.accepted = true; }
            }
        }

        // ── the left: every database and page ───────────────────────────
        Item {
            id: side
            x: 16
            y: 18
            width: 214
            height: pane.height - 36

            Row {
                id: brand
                spacing: 10
                DeskGlyph { anchors.verticalCenter: parent.verticalCenter; size: DeskTheme.textSize + 6 }
                DeskText {
                    text: "Desk"
                    font.family: DeskTheme.fontDisplay
                    strong: true
                    scale: 1.35
                }
            }

            ListView {
                id: list
                anchors.top: brand.bottom
                anchors.topMargin: 16
                anchors.bottom: foot.top
                anchors.bottomMargin: 12
                width: parent.width
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: DeskState.order
                delegate: Rectangle {
                    id: item
                    required property string modelData
                    readonly property bool chosen: modelData === win.name
                    width: list.width
                    height: t.implicitHeight + 14
                    radius: DeskTheme.radiusSmall
                    color: chosen ? DeskTheme.accent : hov.hovered ? DeskTheme.surfaceAlt : "transparent"
                    DeskText {
                        id: t
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 52
                        text: win.label(item.modelData)
                        color: item.chosen ? DeskTheme.onAccent : DeskTheme.text
                        strong: item.chosen
                    }
                    DeskText {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property int n: win.count(item.modelData)
                        visible: n > 0
                        text: String(n)
                        font.family: DeskTheme.fontMono
                        color: item.chosen ? DeskTheme.onAccent : DeskTheme.textMuted
                        scale: 0.8
                    }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: DeskState.pick(item.modelData) }
                }
            }

            Column {
                id: foot
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 6
                DeskText {
                    width: parent.width
                    visible: DeskState.pendingCount > 0
                    text: DeskState.pendingCount === 1 ? "1 change on its way" : `${DeskState.pendingCount} changes on their way`
                    color: DeskTheme.accent
                    scale: 0.8
                }
                DeskText {
                    width: parent.width
                    text: DeskState.badge !== "" ? `${DeskState.badge} · ${DeskState.syncedLabel}` : DeskState.syncedLabel
                    color: DeskState.badge !== "" ? DeskTheme.warn : DeskTheme.textMuted
                    scale: 0.8
                }
                DeskText {
                    width: parent.width
                    visible: DeskState.badge !== "" && DeskState.reason !== ""
                    text: DeskState.reason
                    muted: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    scale: 0.76
                }
                DeskButton {
                    label: DeskState.syncing ? "Syncing…" : "Sync now"
                    enabled: !DeskState.syncing
                    onClicked: DeskState.syncNow()
                }
            }
        }

        Rectangle {
            id: rule
            x: side.x + side.width + 16
            y: 18
            width: 1
            height: pane.height - 36
            color: DeskTheme.line
        }

        // ── the right: a page, or a database's rows and one row ─────────
        Item {
            id: main
            x: rule.x + 1 + 20
            y: 18
            width: pane.width - x - 20
            height: pane.height - 36

            // the title, its description, and what can be done here
            Column {
                id: head
                width: parent.width
                spacing: 6
                Item {
                    width: parent.width
                    height: big.implicitHeight
                    DeskText {
                        id: big
                        width: parent.width - tools.width - 16
                        text: win.label(win.name)
                        font.family: DeskTheme.fontDisplay
                        strong: true
                        scale: 1.5
                    }
                    Row {
                        id: tools
                        anchors.right: parent.right
                        anchors.verticalCenter: big.verticalCenter
                        spacing: 8
                        DeskChip {
                            anchors.verticalCenter: parent.verticalCenter
                            small: true
                            visible: !win.isPage && win.finished > 0
                            label: DeskState.hideFinished ? `Show finished (${win.finished})` : "Hide finished"
                            onClicked: DeskState.setHideFinished(!DeskState.hideFinished)
                        }
                        DeskButton {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "+ New"
                            visible: !win.isPage
                            enabled: !!win.src
                            onClicked: win.startDraft()
                        }
                        DeskButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: win.isPage && !!DeskState.pages[win.name]?.url
                            label: "Open in Notion"
                            onClicked: DeskState.openLink(DeskState.pages[win.name].url)
                        }
                    }
                }
                DeskText {
                    width: parent.width
                    visible: text !== ""
                    text: win.isPage ? "Read-only here: it's written for you" : (win.src?.description ?? "")
                    muted: true
                    scale: 0.86
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                DeskText {
                    width: parent.width
                    visible: DeskState.error !== ""
                    text: DeskState.error
                    color: DeskTheme.danger
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    scale: 0.86
                }
            }

            // a page
            DeskPage {
                visible: win.isPage
                anchors.top: head.bottom
                anchors.topMargin: 14
                width: Math.min(parent.width, 760)
                height: parent.height - y
                page: DeskState.pages[win.name] ?? ({ blocks: [] })
            }

            // a database: its rows…
            Item {
                id: rowsPane
                visible: !win.isPage
                anchors.top: head.bottom
                anchors.topMargin: 14
                width: parent.width - detail.width - 20
                height: parent.height - y

                DeskInput {
                    id: searchBox
                    width: parent.width
                    placeholder: "Search " + win.label(win.name)
                }
                DeskText {
                    anchors.top: searchBox.bottom
                    anchors.topMargin: 24
                    width: parent.width
                    visible: win.rows.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: !DeskState.loaded ? "Waiting for the first sync"
                        : win.query !== "" ? "Nothing matches"
                        : win.finished > 0 && DeskState.hideFinished ? "Everything here is finished"
                        : "Nothing here yet: + New adds a row"
                    muted: true
                }
                ListView {
                    id: rowList
                    anchors.top: searchBox.bottom
                    anchors.topMargin: 10
                    width: parent.width
                    height: parent.height - y
                    clip: true
                    spacing: 3
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.rows
                    delegate: Rectangle {
                        id: r
                        required property var modelData
                        readonly property var row: modelData
                        readonly property bool chosen: row.id === DeskState.selected
                        readonly property string line: win.summary(row)
                        width: rowList.width
                        height: rcol.implicitHeight + 16
                        radius: DeskTheme.radiusSmall
                        color: chosen ? DeskTheme.surfaceAlt : rh.hovered ? Qt.alpha(DeskTheme.surfaceAlt, 0.6) : "transparent"
                        border.color: chosen ? DeskTheme.accent : "transparent"
                        border.width: 1.5
                        opacity: row.closed ? 0.55 : row.ghost ? 0.7 : 1

                        DeskCheck {
                            id: rbox
                            visible: !!win.src?.done
                            x: 10
                            y: 9
                            checked: r.row.v[win.src?.done ?? ""] === true
                            busy: r.row.pending === true
                            TapHandler {
                                enabled: !r.row.ghost
                                onTapped: DeskState.set(win.name, r.row.id, win.src.done, !(r.row.v[win.src.done] === true))
                            }
                        }
                        Column {
                            id: rcol
                            anchors.left: rbox.visible ? rbox.right : parent.left
                            anchors.leftMargin: rbox.visible ? 10 : 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            y: 8
                            spacing: 2
                            DeskText {
                                width: parent.width
                                text: (r.row.v[win.titleProp] || "Untitled") + (r.row.ghost ? "  ·  adding…" : "")
                                strong: true
                                font.strikeout: r.row.closed && !!win.src?.done
                            }
                            DeskText {
                                width: parent.width
                                visible: r.line !== ""
                                text: r.line
                                muted: true
                                scale: 0.84
                            }
                        }
                        HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                        Item {
                            anchors.left: rbox.visible ? rbox.right : parent.left
                            anchors.right: parent.right
                            height: parent.height
                            TapHandler { onTapped: DeskState.selected = r.row.id }
                        }
                    }
                }
            }

            // …and the one chosen
            Rectangle {
                id: detail
                visible: !win.isPage
                anchors.top: head.bottom
                anchors.topMargin: 14
                anchors.right: parent.right
                width: Math.min(420, parent.width * 0.42)
                height: parent.height - y
                radius: DeskTheme.radiusSmall
                color: Qt.alpha(DeskTheme.surface, 0.45)
                border.color: DeskTheme.line

                DeskText {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: !win.sel && !win.drafting
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Pick a row to see all of it and edit it"
                    muted: true
                }

                Flickable {
                    id: form
                    visible: !!win.sel || win.drafting
                    x: 16
                    y: 14
                    width: parent.width - 32
                    height: actions.visible ? actions.y - y - 10 : parent.height - 28
                    contentHeight: fields.implicitHeight + 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: fields
                        width: form.width
                        spacing: 14

                        DeskText {
                            visible: win.drafting
                            text: "New row in " + win.label(win.name)
                            strong: true
                            color: DeskTheme.accent
                        }
                        DeskText {
                            visible: win.sel?.ghost === true
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "On its way to Notion: it can be edited once the next sync brings it back"
                            muted: true
                        }
                        Repeater {
                            model: win.drafting ? win.schema.filter(f => f.edit) : win.schema
                            delegate: DeskField {
                                required property var modelData
                                width: fields.width
                                field: modelData
                                enabled: !(win.sel?.ghost === true)
                                value: win.drafting ? (win.draft[modelData.name] ?? (modelData.type === "checkbox" ? false : null))
                                                    : win.sel?.v[modelData.name] ?? null
                                onCommit: v => {
                                    if (win.drafting) {
                                        const d = Object.assign({}, win.draft);
                                        d[modelData.name] = v;
                                        win.draft = d;
                                    } else if (win.sel && !win.sel.ghost) {
                                        DeskState.set(win.name, win.sel.id, modelData.name, v);
                                    }
                                }
                            }
                        }
                    }
                }

                Flow {
                    id: actions
                    visible: !!win.sel || win.drafting
                    x: 16
                    y: parent.height - height - 14
                    width: parent.width - 32
                    spacing: 8
                    // a new row
                    DeskButton { visible: win.drafting; label: "Add to Notion"; onClicked: win.addDraft() }
                    DeskButton { visible: win.drafting; label: "Cancel"; onClicked: DeskState.selected = "" }
                    // a row
                    DeskButton {
                        visible: !win.drafting && !!win.sel?.url
                        label: "Open in Notion"
                        onClicked: DeskState.openLink(win.sel.url)
                    }
                    DeskButton {
                        visible: !win.drafting && !!win.sel && !win.sel.ghost
                        label: win.confirmTrash ? "Click again: to Notion's trash" : "Move to trash"
                        onClicked: {
                            if (!win.confirmTrash) { win.confirmTrash = true; return; }
                            win.confirmTrash = false;
                            DeskState.trash(win.name, win.sel.id);
                        }
                    }
                }
            }
        }
    }
}
