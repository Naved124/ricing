pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// Spotlight: one glass field in the upper middle of the screen. Apps by
// name, sums worked out as you type ("=" not needed), files from plocate,
// and in clipboard mode (⌘V) the history from cliphist. Enter opens the
// first, arrows move.
Panel {
    id: root

    property bool clip: Shell.open === "clipboard"
    property string query: ""
    property int current: 0
    property var files: []
    property var clips: []

    name: clip ? "clipboard" : "spotlight"
    part: "spotlight"
    paneWidth: 680
    paneHeight: 56 + (results.length ? Math.min(results.length, 8) * 44 + 12 : 0)
    paneX: ((screen ? screen.width : 1920) - paneWidth) / 2
    paneY: (screen ? screen.height : 1080) * 0.22

    readonly property string sum: {
        const q = query.replace(/^=/, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**");
        if (!/^[\d\s+\-*/().,%*]+$/.test(q) || !/\d/.test(q) || !/[+\-*/%]/.test(q)) return "";
        try {
            const v = Function(`"use strict"; return (${q.replace(/,/g, ".")})`)();
            return Number.isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) { return ""; }
    }
    readonly property var results: {
        if (clip) return clips.filter(c => query === "" || c.text.toLowerCase().includes(query.toLowerCase())).slice(0, 30)
                              .map(c => ({ kind: "clip", title: c.text, sub: qsTr("Clipboard"), go: () => Shell.run(["sh", "-c", `cliphist decode ${c.id} | wl-copy`]) }));
        if (query === "") return [];
        const out = [];
        if (sum !== "") out.push({ kind: "sum", title: sum, sub: qsTr("Calculator — Enter copies"), go: () => Shell.run(["wl-copy", sum]) });
        for (const e of Apps.search(query, 6)) out.push({ kind: "app", icon: e.icon, title: e.name, sub: qsTr("Application"), go: () => Apps.launch(e) });
        for (const f of files) out.push({ kind: "file", icon: "text-x-generic", title: f.split("/").pop(), sub: f, go: () => Shell.run(["xdg-open", f]) });
        out.push({ kind: "web", icon: "web-browser", title: qsTr("Search the web for “%1”").arg(query), sub: "",
                   go: () => Shell.run(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(query)]) });
        return out;
    }
    function go(i) {
        const r = results[i];
        if (!r) return;
        Shell.closeAll();
        r.go();
    }

    onShownChanged: if (shown) { query = ""; field.text = ""; current = 0; if (clip) clipReader.running = true; field.forceActiveFocus(); }
    onQueryChanged: { current = 0; if (!clip && query.length > 2) { finder.running = false; finder.running = true; } else files = []; }

    Process {
        id: finder
        command: ["sh", "-c", 'plocate -i -l 6 -- "$1" 2>/dev/null | grep -v "/\\." ', "sh", root.query]
        stdout: StdioCollector { onStreamFinished: root.files = this.text.split("\n").filter(l => l !== "") }
    }
    Process {
        id: clipReader
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clips = this.text.split("\n").filter(l => l !== "").map(l => {
                const t = l.indexOf("\t");
                return { id: l.slice(0, t), text: l.slice(t + 1) };
            })
        }
    }

    Item {
        anchors.fill: parent
        Label {
            x: 18; y: 0; height: 56
            text: root.clip ? "📋" : "⌕"
            font.pixelSize: 22
            secondary: true
        }
        TextInput {
            id: field
            x: 52; y: 0; width: parent.width - 70; height: 56
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.label
            selectionColor: Theme.selection
            font.family: Theme.fontDisplay
            font.pixelSize: 24
            focus: true
            onTextChanged: root.query = text
            Keys.onEscapePressed: Shell.closeAll()
            Keys.onReturnPressed: root.go(root.current)
            Keys.onDownPressed: root.current = Math.min(root.results.length - 1, root.current + 1)
            Keys.onUpPressed: root.current = Math.max(0, root.current - 1)
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === ""
                text: root.clip ? qsTr("Clipboard History") : qsTr("Spotlight Search")
                font: field.font
                color: Theme.label3
            }
        }
        Rectangle { y: 56; width: parent.width; height: 1; color: Theme.separator; visible: root.results.length > 0 }
        Column {
            y: 62; x: 6
            width: parent.width - 12
            Repeater {
                model: root.results.slice(0, 8)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: parent.width; height: 44; radius: 10
                    color: root.current === index ? Theme.accent : "transparent"
                    AppIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; implicitSize: 28; app: row.modelData.icon || ""; visible: !!row.modelData.icon }
                    Column {
                        x: 48; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60
                        Label { width: parent.width; text: row.modelData.title; color: root.current === row.index ? Theme.onAccent : Theme.label; maximumLineCount: 1 }
                        Label { width: parent.width; text: row.modelData.sub; visible: text !== ""; font.pixelSize: Theme.smallSize; color: root.current === row.index ? Theme.onAccent : Theme.label2 }
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.current = row.index; onClicked: root.go(row.index) }
                }
            }
        }
    }
}
