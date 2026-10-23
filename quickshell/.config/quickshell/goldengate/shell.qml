//@ pragma UseQApplication

// Golden Gate — macOS 27 on Hyprland, in behaviour as well as looks.
// Run with `qs -c goldengate` (the `rice` script does this when Golden Gate
// is active); `gg` drives it over IPC.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services
import qs.wallpaper

ShellRoot {
    // the desktop picture, one per screen, under everything
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    // qs -c goldengate ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function ping(): string { return "pong"; }
        // the accent and glass the shell is wearing, for gg and the tests
        function look(): string {
            return JSON.stringify({ mode: Theme.dark ? "dark" : "light", k: Theme.k, accent: Theme.accentName,
                                    accentColor: String(Theme.accent), glass: Theme.glassMode, clarity: Theme.clarity,
                                    font: Theme.fontUi });
        }
    }
}
