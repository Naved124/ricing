pragma ComponentBehavior: Bound

import QtQuick

// One property of a row in the full view, edited the way its type asks:
// text in a box (several lines for a text property), numbers, links and the
// like in a one-line box, a checkbox, an option's chips (tap the lit one of a
// select to clear it), a multi-select's chips, a date with Today / Tomorrow /
// Next week / Clear. Worked-out properties (formulas, created and edited
// times, people, relations) are shown, not edited. `commit` carries the new
// value as desk-sync set takes it (schema.py); the view decides whether that
// goes to Notion or into a new row's draft.
Column {
    id: f

    required property var field             // { name, type, edit, options }
    property var value: null
    signal commit(var value)

    readonly property string type: field.type
    readonly property bool editable: field.edit === true
    readonly property bool texty: ["title", "rich_text", "url", "email", "phone_number", "number"].indexOf(type) >= 0
    readonly property var options: field.options ?? []

    spacing: 5

    function iso(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function shifted(days) {
        const d = new Date(new Date(DeskState.now).toDateString());
        d.setDate(d.getDate() + days);
        return iso(d);
    }
    function setDate(start) {
        if (!start) { f.commit(null); return; }
        const end = f.value?.end ?? null;
        f.commit({ start: start, end: end && end >= start ? end : null });
    }
    function sendText(t) {
        if (type === "number") {
            const s = t.trim();
            if (s === "") { f.commit(null); return; }
            const n = Number(s.replace(",", "."));
            if (!isFinite(n)) { DeskState.say(`${field.name} should be a number`); return; }
            f.commit(n);
            return;
        }
        const clean = DeskState.cleanText(t, type === "rich_text");
        if (type === "title" && clean === "") { DeskState.say("the title can't be empty"); return; }
        f.commit(clean);
    }
    function sendDate(t) {
        const s = t.trim();
        if (s === "") { f.commit(null); return; }
        if (!/^\d{4}-\d\d-\d\d([ T]\d\d:\d\d)?$/.test(s) || isNaN(new Date(s.slice(0, 10) + "T00:00:00"))) {
            DeskState.say("write a date as 2026-11-02 (or 2026-11-02 14:30)");
            return;
        }
        if (s.length === 10) { setDate(s); return; }
        const d = new Date(s.replace(" ", "T"));
        const off = -d.getTimezoneOffset();
        const pad = n => String(Math.floor(Math.abs(n))).padStart(2, "0");
        setDate(`${s.slice(0, 10)}T${s.slice(11, 16)}:00${off >= 0 ? "+" : "-"}${pad(off / 60)}:${pad(off % 60)}`);
    }

    // the property's name, and its type when it's worked out by Notion
    DeskText {
        text: f.field.name + (f.editable ? "" : "  ·  from Notion")
        muted: true
        strong: true
        scale: 0.78
    }

    // text, numbers, links
    DeskInput {
        visible: f.editable && f.texty
        width: f.width
        multi: f.type === "rich_text"
        mono: f.type === "number"
        maxLength: f.type === "title" ? 2000 : 10000
        text: f.value === null || f.value === undefined ? "" : String(f.value)
        placeholder: f.type === "url" ? "https://…" : f.type === "number" ? "a number" : "Empty"
        onAccepted: t => f.sendText(t)
    }
    // a link opens on a click, https only
    DeskButton {
        visible: f.type === "url" && /^https:\/\//.test(f.value ?? "")
        label: "Open link"
        onClicked: DeskState.openLink(f.value)
    }

    // a checkbox
    Row {
        visible: f.type === "checkbox"
        spacing: 10
        DeskCheck {
            id: tick
            checked: f.value === true
            enabled: f.editable
            TapHandler { enabled: f.editable; onTapped: f.commit(!(f.value === true)) }
        }
        DeskText {
            anchors.verticalCenter: tick.verticalCenter
            text: f.value === true ? "Yes" : "No"
            muted: f.value !== true
        }
    }

    // a select or a status: one option; a multi-select: any of them
    Flow {
        visible: f.type === "select" || f.type === "status" || f.type === "multi_select"
        width: f.width
        spacing: 6
        Repeater {
            model: f.options
            delegate: DeskChip {
                required property var modelData
                label: modelData.name
                enabled: f.editable
                on: f.type === "multi_select" ? (f.value ?? []).indexOf(modelData.name) >= 0 : f.value === modelData.name
                onClicked: {
                    const name = modelData.name;
                    if (f.type === "multi_select") {
                        const now = f.value ?? [];
                        const next = now.indexOf(name) >= 0 ? now.filter(x => x !== name) : now.concat([name]);
                        f.commit(f.options.map(o => o.name).filter(n => next.indexOf(n) >= 0));
                    } else if (f.type === "select" && f.value === name) {
                        f.commit("");
                    } else {
                        f.commit(name);
                    }
                }
            }
        }
    }

    // a date
    Column {
        visible: f.type === "date" && f.editable
        width: f.width
        spacing: 6
        Row {
            width: parent.width
            spacing: 10
            DeskInput {
                id: dateBox
                width: 170
                mono: true
                maxLength: 16
                text: (f.value?.start ?? "").replace("T", " ").slice(0, 16)
                placeholder: "2026-11-02"
                onAccepted: t => f.sendDate(t)
            }
            DeskText {
                anchors.verticalCenter: dateBox.verticalCenter
                text: DeskState.show(f.field, f.value)
                muted: true
            }
        }
        Flow {
            width: parent.width
            spacing: 6
            DeskChip { small: true; label: "Today"; onClicked: f.setDate(f.shifted(0)) }
            DeskChip { small: true; label: "Tomorrow"; onClicked: f.setDate(f.shifted(1)) }
            DeskChip { small: true; label: "Next week"; onClicked: f.setDate(f.shifted(7)) }
            DeskChip { small: true; label: "Clear"; visible: !!f.value; onClicked: f.commit(null) }
        }
    }

    // worked out by Notion, or a type the view can't edit
    DeskText {
        visible: !f.editable && f.type !== "checkbox" && f.type !== "select" && f.type !== "status" && f.type !== "multi_select"
        width: f.width
        text: DeskState.show(f.field, f.value) || "—"
        wrapMode: Text.Wrap
        maximumLineCount: 8
    }
}
