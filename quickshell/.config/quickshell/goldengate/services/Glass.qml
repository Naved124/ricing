pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The glass that's actually on screen: `gg glass` writes it to
// ~/.local/state/goldengate/glass.json after loading (or failing to load)
// the plugin. Settings says what the user asked for; this says what they got,
// and why not when Liquid had to fall back to Frosted.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                                   + "/goldengate/glass.json"

    // until gg has run, what Settings asks for
    readonly property string want: state.want || Settings.glassMode
    readonly property string mode: Settings.accessibility.reduceTransparency ? "solid" : (state.mode || Settings.glassMode)
    readonly property string backend: state.backend || "hyprland"
    readonly property string reason: state.reason || ""
    // hyprglass or hyprliquid bends and lights the panels: the shell then
    // draws only its tint, with shadows faint enough to fall under the
    // plugin's mask
    readonly property bool plugin: mode === "liquid" && (backend === "hyprglass" || backend === "hyprliquid")
    // Liquid was asked for and isn't there
    readonly property bool fellBack: want === "liquid" && mode !== "liquid" && reason !== ""

    property var state: ({})
    // Liquid fell back (or fell back for another reason): once per change
    signal fell(string reason)

    FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const was = root.fellBack ? root.reason : "";
            try { root.state = JSON.parse(text()); } catch (e) { root.state = {}; }
            if (root.fellBack && root.reason !== was)
                root.fell(root.reason);
        }
        onLoadFailed: root.state = {}
    }
}
