pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The wastebasket. Every window that opens is noted (its class, title and
// the command that started it, read from /proc/<pid>/cmdline); when it
// closes it is crumpled into the bin: pushed onto a stack of the last 20.
// Fishing one out runs its command again. Floating windows (dialogs,
// pickers) and the helpers the shell opens itself never go in.
// The stack is kept in the shell's state, so it outlives a restart.
Singleton {
    id: root

    readonly property int maxStack: 20
    readonly property int maxShown: 9
    readonly property var stack: saved.stack          // oldest first: [{ cls, title, cmd, seed }]
    readonly property int count: stack.length

    // address → { cls, title, cmd, floating }
    property var open: ({})
    // classes the shell is about to open itself (nmtui, pavucontrol…): class → expiry time
    property var expected: ({})

    signal tossed()          // the bin was emptied (the widget plays the toss)

    function expect(cls) {
        const e = Object.assign({}, expected);
        e[cls.toLowerCase()] = Date.now() + 15000;
        expected = e;
    }

    function isExpected(cls) {
        const until = expected[(cls || "").toLowerCase()];
        return !!until && until > Date.now();
    }

    // the most recently binned app back out: run its command again
    function fishOut() {
        if (!stack.length) return null;
        const item = stack[stack.length - 1];
        saved.stack = stack.slice(0, -1);
        relaunch(item);
        return item;
    }

    function relaunch(item) {
        if (item.cmd && item.cmd.length)
            Quickshell.execDetached(item.cmd);
        else if (item.cls)
            Quickshell.execDetached(["gtk-launch", item.cls]);
    }

    function empty() {
        if (!stack.length) return;
        saved.stack = [];
        tossed();
    }

    // the launcher opened this desktop entry: take its sheet out of the bin
    function takeOut(entry) {
        const names = [entry.startupClass, entry.id, entry.name, (entry.command ?? [])[0]]
            .filter(n => n).map(n => String(n).toLowerCase().replace(/\.desktop$/, "").split("/").pop());
        for (let i = stack.length - 1; i >= 0; i--) {
            const it = stack[i];
            const cls = (it.cls || "").toLowerCase();
            const exe = String((it.cmd ?? [])[0] ?? "").toLowerCase().split("/").pop();
            if (names.some(n => n === cls || n === exe || cls.endsWith("." + n) || n.endsWith("." + cls))) {
                const s = stack.slice();
                s.splice(i, 1);
                saved.stack = s;
                return true;
            }
        }
        return false;
    }

    function noted(info) {
        if (!info || !info.address) return;
        const o = Object.assign({}, open);
        o[info.address.replace(/^0x/, "")] = {
            cls: info.class || "",
            title: info.title || "",
            cmd: info.cmd || [],
            floating: !!info.floating,
            skip: isExpected(info.class),
        };
        open = o;
    }

    function closed(address) {
        const rec = open[address];
        if (!rec) return;
        const o = Object.assign({}, open);
        delete o[address];
        open = o;
        if (rec.floating || rec.skip) return;
        const s = stack.concat([{ cls: rec.cls, title: rec.title, cmd: rec.cmd, seed: Math.floor(Math.random() * 1e9) }]);
        saved.stack = s.slice(Math.max(0, s.length - maxStack));
    }

    // one lookup per window: class, title, floating and the command line
    Component {
        id: lookup
        Process {
            id: proc
            property string which: "all"
            running: true
            command: ["sh", "-c", `
                sleep 0.2
                hyprctl clients -j | jq -c --arg a "$1" '.[] | select($a == "all" or .address == ("0x" + $a))
                    | {address, class, title, floating, pid}' |
                while IFS= read -r c; do
                    pid=$(printf '%s' "$c" | jq -r .pid)
                    cmd=$(tr '\\0' '\\n' < "/proc/$pid/cmdline" 2>/dev/null | jq -Rsc 'split("\\n") | map(select(. != ""))')
                    printf '%s' "$c" | jq -c --argjson cmd "\${cmd:-[]}" '. + {cmd: $cmd}'
                done`, "sh", which]
            stdout: SplitParser {
                onRead: line => {
                    try { root.noted(JSON.parse(line)); } catch (e) {}
                }
            }
            onExited: proc.destroy()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE   closewindow>>ADDRESS
            if (event.name === "openwindow") {
                const address = event.data.split(",")[0];
                lookup.createObject(root, { which: address });
            } else if (event.name === "closewindow") {
                root.closed(event.data.split(",")[0]);
            }
        }
    }

    // windows that were open before the shell started
    Component.onCompleted: lookup.createObject(root, { which: "all" })

    FileView {
        path: Quickshell.statePath("bin.json")
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: saved
            property var stack: []
        }
    }
}
