pragma ComponentBehavior: Bound

import QtQuick
import qs.common
import Quickshell
import Quickshell.Io
import qs.services
import "calc.js" as Calc

// The launcher's brain: turns (mode, query) into result rows.
// A row is { title, desc, iconName | glyph | emoji, action, mono, run }.
// run() does the thing and returns true to keep the launcher open.
Item {
    id: root

    property string mode: ""
    property string query: ""
    property int limit: 7

    property var results: []
    property string empty: ""

    signal done(string icon, string message)

    readonly property var modes: [
        { key: "=", name: "calculator", icon: "calculator", placeholder: "2^10, sqrt 2, 15% of… (= 0.15*…)" },
        { key: "/", name: "files", icon: "folder", placeholder: "Find a file in your home" },
        { key: ":", name: "emoji", icon: "emoji", placeholder: "Search emoji by name" },
        { key: ">", name: "run", icon: "terminal", placeholder: "A shell command" },
        { key: "?", name: "web", icon: "globe", placeholder: "Search the web" },
        { key: "!", name: "clipboard", icon: "clipboard", placeholder: "Search clipboard history" },
    ]
    readonly property string modeKeys: modes.map(m => m.key).join("")
    readonly property var modeInfo: modes.find(m => m.key === mode)
        ?? { key: "", name: "", icon: "search", placeholder: "Search apps, or start with = / : > ? !" }

    onModeChanged: {
        if (mode === "!") clipProc.running = true;
        refresh();
    }
    onQueryChanged: refresh()

    // called each time the launcher opens
    function start(m) {
        if (mode === m) {
            if (m === "!") clipProc.running = true;
            refresh();
        } else {
            mode = m;
        }
    }

    function refresh() {
        const q = query.trim();
        switch (mode) {
        case "=": return calc(q);
        case "/": return files(q);
        case ":": return emoji(q);
        case ">": return shell(q);
        case "?": return web(q);
        case "!": return clipboard(q);
        default: return apps(q);
        }
    }

    function set(rows, emptyText) {
        results = rows.slice(0, limit);
        empty = rows.length ? "" : emptyText;
    }

    function copy(text, what) {
        Quickshell.execDetached(["wl-copy", "--", text]);
        done("clipboard", `Copied ${what}`);
        return false;
    }

    // ── apps ────────────────────────────────────────────────────────────
    // the desktop-entry scan is asynchronous (and reruns when apps are installed)
    Connections {
        target: Apps
        function onEntriesChanged() { if (root.mode === "") root.refresh(); }
    }

    function apps(q) {
        set(Apps.search(q, limit).map(e => ({
            title: e.name,
            desc: e.comment || e.genericName || "",
            iconName: e.icon,
            glyph: "app",
            action: "open",
            run: () => { Apps.launch(e); return false; },
        })), q ? `No apps match “${q}”` : "No applications found");
    }

    // ── = calculator ────────────────────────────────────────────────────
    function calc(q) {
        if (!q) return set([], "Type a sum: 12*7, (3+4)^2, sqrt 2, sin(pi/4)");
        const r = Calc.evaluate(q);
        if (!r.ok) return set([], r.error);
        set([{
            title: r.text,
            desc: `${q} =`,
            glyph: "calculator",
            mono: true,
            action: "copy",
            run: () => copy(r.text, r.text),
        }], "");
    }

    // ── / files ─────────────────────────────────────────────────────────
    function files(q) {
        fileTimer.stop();
        if (q.length < 2) return set([], "Type at least two letters");
        fileTimer.restart();
    }

    Timer {
        id: fileTimer
        interval: 120
        onTriggered: {
            fileProc.running = false;
            fileProc.command = ["sh", "-c", `
                q=$1
                if command -v fd >/dev/null; then fd -i --max-results 40 --exclude .git -- "$q" "$HOME"
                elif command -v fdfind >/dev/null; then fdfind -i --max-results 40 --exclude .git -- "$q" "$HOME"
                else find "$HOME" -iname "*$q*" -not -path '*/.*' 2>/dev/null | head -n 40
                fi`, "sh", root.query.trim()];
            fileProc.running = true;
        }
    }

    Process {
        id: fileProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.mode !== "/") return;
                const home = Quickshell.env("HOME");
                const rows = text.split("\n").filter(l => l).map(path => {
                    const dir = path.endsWith("/");
                    const clean = dir ? path.slice(0, -1) : path;
                    const name = clean.slice(clean.lastIndexOf("/") + 1);
                    const parent = clean.slice(0, clean.lastIndexOf("/")).replace(home, "~");
                    return {
                        title: name,
                        desc: parent || "/",
                        glyph: dir ? "folder" : "file",
                        action: "open",
                        run: () => { Quickshell.execDetached(["xdg-open", clean]); return false; },
                    };
                });
                // shallow paths first: closer to home is usually what you meant
                rows.sort((a, b) => a.desc.split("/").length - b.desc.split("/").length);
                root.set(rows, `No files match “${root.query.trim()}”`);
            }
        }
    }

    // ── : emoji ─────────────────────────────────────────────────────────
    property var emojiList: []

    FileView {
        path: Quickshell.shellPath("launcher/emoji.json")
        blockLoading: true
        onLoaded: root.emojiList = JSON.parse(text())
    }

    function emoji(q) {
        const words = q.toLowerCase().split(/\s+/).filter(w => w);
        // whole-word matches first, then shorter (plainer) names
        const rank = name => {
            const parts = name.split(" ");
            return (words.every(w => parts.includes(w)) ? 0 : words.every(w => parts.some(p => p.startsWith(w))) ? 1 : 2) * 100 + name.length;
        };
        const hits = emojiList
            .filter(([, name]) => words.every(w => name.includes(w)))
            .sort((a, b) => rank(a[1]) - rank(b[1]))
            .slice(0, limit)
            .map(([ch, name]) => ({
                title: name.replace(/\b\w/g, c => c.toUpperCase()),
                desc: "",
                emoji: ch,
                action: "copy",
                run: () => copy(ch, ch),
            }));
        set(hits, `No emoji called “${q}”`);
    }

    // ── > shell ─────────────────────────────────────────────────────────
    function shell(q) {
        if (!q) return set([], "Runs with sh -c, or in kitty (the second row)");
        set([
            {
                title: q,
                desc: "Run in the background",
                glyph: "terminal",
                mono: true,
                action: "run",
                run: () => { Quickshell.execDetached(["sh", "-c", q]); return false; },
            },
            {
                title: q,
                desc: "Run in kitty, and keep the window open",
                glyph: "terminal",
                mono: true,
                action: "run in kitty",
                run: () => { Quickshell.execDetached(["kitty", "--hold", "sh", "-c", q]); return false; },
            },
        ], "");
    }

    // ── ? web ───────────────────────────────────────────────────────────
    function web(q) {
        if (!q) return set([], "Searches with DuckDuckGo");
        const rows = [];
        if (/^(https?:\/\/)?[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(q)) {
            const url = q.includes("://") ? q : `https://${q}`;
            rows.push({
                title: url,
                desc: "Open this address",
                glyph: "globe",
                action: "open",
                run: () => { Quickshell.execDetached(["xdg-open", url]); return false; },
            });
        }
        rows.push({
            title: q,
            desc: "Search the web",
            glyph: "search",
            action: "search",
            run: () => {
                Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(q)]);
                return false;
            },
        });
        set(rows, "");
    }

    // ── ! clipboard (cliphist) ──────────────────────────────────────────
    property var clipLines: []

    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipLines = text.split("\n").filter(l => l);
                if (root.mode === "!") root.refresh();
            }
        }
        onExited: code => {
            if (code !== 0 && root.mode === "!") root.set([], "Clipboard history needs cliphist");
        }
    }

    function clipboard(q) {
        const needle = q.toLowerCase();
        const rows = [];
        for (const line of clipLines) {
            const tab = line.indexOf("\t");
            const body = line.slice(tab + 1);
            if (needle && !body.toLowerCase().includes(needle)) continue;
            const binary = body.startsWith("[[ binary data");
            rows.push({
                title: binary ? body.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : body.replace(/\s+/g, " "),
                desc: binary ? "Image" : "",
                glyph: binary ? "app" : "clipboard",
                mono: !binary,
                action: "copy",
                run: () => {
                    Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", line]);
                    root.done("clipboard", "Copied from history");
                    return false;
                },
            });
            if (rows.length >= limit) break;
        }
        set(rows, clipLines.length ? `Nothing in history matches “${q}”` : "Clipboard history is empty");
    }
}
