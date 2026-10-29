pragma ComponentBehavior: Bound

import QtQuick

// A page in the full view (the daily brief, the weekly reviews), read-only,
// block by block as plain text; your scheduled agents write them. Its
// subpages (the weekly recaps, newest first) follow, each under its title.
Flickable {
    id: list

    property var page: ({ title: "", blocks: [] })

    contentHeight: col.implicitHeight + 12
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    // one list: the page's blocks, then each subpage's title and blocks;
    // numbered items count up within a run of them
    readonly property var blocks: {
        const out = [];
        const add = (bs, n) => {
            for (const b of bs ?? []) {
                n = b.kind === "number" ? n + 1 : 0;
                out.push(Object.assign({ n: n }, b));
            }
        };
        add(page.blocks, 0);
        for (const p of page.pages ?? []) {
            out.push({ kind: "divider", text: "", n: 0 });
            out.push({ kind: "h1", text: p.title, n: 0 });
            add(p.blocks, 0);
        }
        return out;
    }

    Column {
        id: col
        x: 6
        width: list.width - 12
        spacing: 7

        DeskText {
            width: parent.width
            visible: list.blocks.length === 0
            text: DeskState.loaded ? "Nothing on this page yet" : "Waiting for the first sync"
            muted: true
        }

        Repeater {
            model: list.blocks
            delegate: Item {
                id: blk
                required property var modelData
                readonly property var b: modelData
                readonly property bool heading: b.kind === "h1" || b.kind === "h2" || b.kind === "h3"
                readonly property string lead: b.kind === "bullet" ? "•" : b.kind === "number" ? b.n + "." : ""
                width: col.width
                height: b.kind === "divider" ? 9 : Math.max(body.implicitHeight, box.visible ? box.height : 0)
                            + (b.kind === "callout" || b.kind === "code" ? 12 : 0) + (heading ? 4 : 0)

                Rectangle {
                    visible: blk.b.kind === "divider"
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: DeskTheme.line
                }
                Rectangle {
                    visible: blk.b.kind === "callout" || blk.b.kind === "code"
                    anchors.fill: parent
                    radius: DeskTheme.radiusSmall
                    color: DeskTheme.surfaceAlt
                }
                Rectangle {
                    visible: blk.b.kind === "quote"
                    width: 3
                    height: parent.height
                    radius: 1.5
                    color: DeskTheme.accent
                }
                DeskCheck {
                    id: box
                    visible: blk.b.kind === "todo"
                    y: 2
                    size: DeskTheme.textSize + 2
                    checked: blk.b.checked === true
                }
                DeskText {
                    visible: blk.lead !== ""
                    width: 18
                    text: blk.lead
                    muted: true
                    font.family: blk.b.kind === "number" ? DeskTheme.fontMono : DeskTheme.fontBody
                }
                DeskText {
                    id: body
                    visible: blk.b.kind !== "divider"
                    x: blk.lead !== "" || box.visible ? 24 : blk.b.kind === "quote" ? 12 : blk.b.kind === "callout" || blk.b.kind === "code" ? 10 : 0
                    y: blk.b.kind === "callout" || blk.b.kind === "code" ? 6 : blk.heading ? 4 : 0
                    width: parent.width - x - (blk.b.kind === "callout" || blk.b.kind === "code" ? 10 : 0)
                    text: blk.b.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 40
                    strong: blk.heading
                    scale: blk.b.kind === "h1" ? 1.3 : blk.b.kind === "h2" ? 1.18 : blk.b.kind === "h3" ? 1.06 : 1
                    font.family: blk.b.kind === "code" ? DeskTheme.fontMono : blk.heading ? DeskTheme.fontDisplay : DeskTheme.fontBody
                    font.italic: blk.b.kind === "quote"
                    font.strikeout: blk.b.kind === "todo" && blk.b.checked === true
                    muted: blk.b.kind === "todo" && blk.b.checked === true
                }
            }
        }
    }
}
