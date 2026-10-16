pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.services
import "calc.js" as Calc

// The launcher (Super, Super+Space): an index card on a dimmed desk. A
// 430-wide ruled card turned −1.2° with a red margin line; you write on
// it in Kalam above a dashed pencil line ("what do you need?"). Up to seven
// apps, matched loosely on name, generic name and keywords: the name in
// pencil, what it is in graphite. The chosen one turns ink-blue with a red
// arrow in the margin.
//   =  sums (Nacre's calculator: parsed, never evaluated as code)
//   Super+V opens it on the clipboard history (cliphist)
// Hyprland drops the card in from the top; Esc or a click outside tosses it.
PanelWindow {
    id: win

    readonly property bool open: Shell.launcherOpen
    readonly property bool clipboard: Shell.launcherMode === "!"
    readonly property int maxRows: 7
    readonly property int rowHeight: 32
    readonly property int marginX: 52
    property bool leaving: false

    screen: Hypr.focusedScreen
    visible: open || leaving
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "paper-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var results: []
    property int current: 0
    property string empty: ""

    onOpenChanged: {
        if (open) {
            toss.stop();
            leaving = false;
            card.y = card.restY;
            card.opacity = 1;
            card.turn = 0;
            field.text = Shell.launcherText;
            current = 0;
            if (clipboard) clipProc.running = true;
            refresh();
            field.forceActiveFocus();
            focusTimer.restart();
        } else if (!leaving) {
            leaving = true;
            toss.start();
        }
    }
    // the layer surface maps a moment after `open`, and focus asked for before
    // that can be lost; keep asking until typing lands in the field
    Timer {
        id: focusTimer
        interval: 30
        repeat: true
        property int tries: 0
        onTriggered: {
            field.forceActiveFocus();
            if (field.activeFocus || ++tries > 20) { stop(); tries = 0; }
        }
    }

    function close() { Shell.launcherOpen = false; }

    function refresh() {
        const q = field.text.trim();
        if (clipboard) return clips(q);
        if (q.startsWith("=")) return calc(q.slice(1).trim());
        const found = Apps.search(q, maxRows).map(e => ({
            title: e.name,
            desc: e.genericName || "",
            run: () => Apps.launch(e),
        }));
        results = found;
        empty = q ? "nothing by that name" : "no applications found";
        current = 0;
    }

    function calc(q) {
        if (!q) { results = []; empty = "a sum: 12*7, (3+4)^2, sqrt 2"; return; }
        const r = Calc.evaluate(q);
        if (!r.ok) { results = []; empty = r.error; return; }
        results = [{
            title: "= " + r.text,
            desc: "copy",
            mono: true,
            run: () => Quickshell.execDetached(["wl-copy", "--", r.text]),
        }];
        current = 0;
    }

    // ── clipboard history (cliphist) ────────────────────────────────────
    property var clipLines: []
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.clipLines = text.split("\n").filter(l => l);
                if (win.clipboard) win.refresh();
            }
        }
        onExited: code => {
            if (code !== 0 && win.clipboard) { win.results = []; win.empty = "clipboard history needs cliphist"; }
        }
    }

    function clips(q) {
        const needle = q.toLowerCase();
        const rows = [];
        for (const line of clipLines) {
            const body = line.slice(line.indexOf("\t") + 1);
            if (needle && !body.toLowerCase().includes(needle)) continue;
            const binary = body.startsWith("[[ binary data");
            rows.push({
                title: binary ? "an image" : body.replace(/\s+/g, " "),
                desc: binary ? body.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : "",
                mono: !binary,
                run: () => Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", line]),
            });
            if (rows.length >= maxRows) break;
        }
        results = rows;
        empty = clipLines.length ? "nothing like that was copied" : "nothing copied yet";
        current = 0;
    }

    function activate(i) {
        const r = results[i];
        if (!r) return;
        r.run();
        close();
    }

    function step(by) {
        if (!results.length) return;
        current = (current + by + results.length) % results.length;
    }

    // the desk, dimmed
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: card.opacity
        MouseArea {
            anchors.fill: parent
            onClicked: win.close()
        }
    }

    Sheet {
        id: card

        readonly property real restY: Math.round(win.height * 0.2)
        property real turn: 0               // extra spin while being tossed

        x: Math.round((win.width - width) / 2)
        y: restY
        width: 430
        height: column.y + column.height + 22
        seed: 430
        tilt: -1.2 + turn
        ruled: true
        ruleGap: win.rowHeight
        ruleTop: list.y + win.rowHeight - 1 - 2 * win.rowHeight
        margin: true
        marginX: win.marginX

        MouseArea { anchors.fill: parent }   // clicks on the card stay on it

        Column {
            id: column
            x: 70
            y: 30
            width: card.width - 70 - 32
            spacing: 6

            TextField {
                id: field
                width: parent.width
                height: 40
                leftPadding: 0
                placeholderText: win.clipboard ? "what did you copy?" : "what do you need?"
                placeholderTextColor: Theme.graphite
                color: Theme.ink
                selectionColor: Theme.sticky
                selectedTextColor: Theme.carbon
                font.family: Theme.fontHand
                font.pixelSize: 22
                background: Item {
                    // a dashed pencil line to write on
                    Shape {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        ShapePath {
                            strokeColor: Theme.graphite
                            strokeWidth: 1.5
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [3, 2.5]
                            startX: 0
                            startY: 1
                            PathLine { x: field.width; y: 1 }
                        }
                    }
                }
                cursorDelegate: Rectangle {
                    id: caret
                    width: 2
                    color: Theme.ink
                    visible: field.activeFocus
                    SequentialAnimation on opacity {
                        running: caret.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 500 }
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 500 }
                    }
                }

                onTextChanged: win.refresh()

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    if (event.key === Qt.Key_Escape) win.close();
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_J)) win.step(1);
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_K)) win.step(-1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.activate(win.current);
                    else return;
                    event.accepted = true;
                }
            }

            Column {
                id: list
                width: parent.width

                Repeater {
                    model: win.results

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === win.current

                        width: list.width
                        height: win.rowHeight

                        // the arrow in the margin
                        Hand {
                            x: -32
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            visible: row.chosen
                            text: "→"
                            size: 20
                            color: Theme.red
                        }

                        Row {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            width: parent.width
                            spacing: 8
                            clip: true

                            Text {
                                id: name
                                text: row.modelData.title
                                color: row.chosen ? Theme.ink : Theme.pencil
                                font.family: row.modelData.mono ? Theme.fontType : Theme.fontHand
                                font.pixelSize: row.modelData.mono ? 17 : 20
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, list.width - (desc.text ? Math.min(desc.implicitWidth, 120) + 8 : 0))
                                textFormat: Text.PlainText
                            }
                            Hand {
                                id: desc
                                anchors.baseline: name.baseline
                                text: row.modelData.desc ?? ""
                                size: 14
                                color: Theme.graphite
                                elide: Text.ElideRight
                                width: Math.max(0, list.width - name.width - 8)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.current = row.index
                            onClicked: win.activate(row.index)
                        }
                    }
                }

                Hand {
                    visible: win.results.length === 0
                    height: win.rowHeight
                    verticalAlignment: Text.AlignBottom
                    bottomPadding: 2
                    text: win.empty
                    size: 18
                    color: Theme.graphite
                }
            }
        }
    }

    // Esc: the card is tossed down off the desk
    ParallelAnimation {
        id: toss
        NumberAnimation { target: card; property: "y"; to: card.restY + 160; duration: Theme.durPanelOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.toss }
        NumberAnimation { target: card; property: "turn"; to: 1.5; duration: Theme.durPanelOut }
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.durPanelOut; easing.type: Easing.InQuad }
        onFinished: win.leaving = false
    }
}
