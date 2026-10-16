pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Installed applications for the launcher, ranked by how well they match
// (name, generic name, keywords; exact, prefix, then letters in order)
// and by how often they have been opened. Launch counts live in
// ~/.local/state/rice/launcher.json so every rice shares them.
Singleton {
    id: root

    readonly property var entries: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    function count(entry) {
        return saved.counts[entry.id] ?? 0;
    }

    // 0 when it doesn't match at all
    function score(entry, q) {
        const name = entry.name.toLowerCase();
        let s = 0;
        if (name === q) s = 100;
        else if (name.startsWith(q)) s = 80;
        else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) s = 65;
        else if (name.includes(q)) s = 50;
        else if ((entry.genericName || "").toLowerCase().includes(q)) s = 35;
        else if (entry.keywords.some(k => k.toLowerCase().startsWith(q))) s = 30;
        else if (entry.id.toLowerCase().includes(q)) s = 25;
        else if ((entry.comment || "").toLowerCase().includes(q)) s = 15;
        else if (subsequence(name, q)) s = 10;
        // fuzzy: the letters in order in the generic name or a keyword
        else if (subsequence((entry.genericName || "").toLowerCase(), q)) s = 7;
        else if (entry.keywords.some(k => subsequence(k.toLowerCase(), q))) s = 5;
        return s;
    }

    function subsequence(text, q) {
        let i = 0;
        for (const c of text) if (c === q[i] && ++i === q.length) return true;
        return false;
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        const boost = e => 8 * Math.log2(1 + count(e));
        if (q === "") {
            return entries.slice()
                .sort((a, b) => count(b) - count(a) || a.name.localeCompare(b.name))
                .slice(0, limit);
        }
        return entries
            .map(e => ({ e, s: score(e, q) }))
            .filter(r => r.s > 0)
            .sort((a, b) => (b.s + boost(b.e)) - (a.s + boost(a.e)) || a.e.name.localeCompare(b.e.name))
            .slice(0, limit)
            .map(r => r.e);
    }

    function launch(entry) {
        Bin.takeOut(entry);   // reopening an app takes its sheet out of the bin
        const counts = Object.assign({}, saved.counts);
        counts[entry.id] = (counts[entry.id] ?? 0) + 1;
        saved.counts = counts;

        // execute() ignores Terminal=true, so wrap those in kitty ourselves
        if (entry.runInTerminal) {
            Quickshell.execDetached({
                command: ["kitty", "--", ...entry.command],
                workingDirectory: entry.workingDirectory || Quickshell.env("HOME"),
            });
        } else {
            entry.execute();
        }
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice/launcher.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: saved
            property var counts: ({})
        }
    }
}
