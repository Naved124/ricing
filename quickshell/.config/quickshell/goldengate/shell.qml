//@ pragma UseQApplication

// Golden Gate — macOS 27 on Hyprland, in behaviour as well as looks.
// Run with `qs -c goldengate` (the `rice` script does this when Golden Gate
// is active); `gg` drives it over IPC.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.notifications
import qs.services
import qs.wallpaper

ShellRoot {
    // the desktop picture, one per screen, under everything
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    // the system's banners (Liquid Glass falling back), on the first screen
    Banner {
        id: banner
        screen: Quickshell.screens[0]
    }
    Connections {
        target: Glass
        function onFell(reason) {
            banner.show(qsTr("Liquid Glass is unavailable"), qsTr("Using Frosted glass instead: %1.").arg(reason));
        }
    }

    // qs -c goldengate ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function ping(): string { return "pong"; }
        // the accent and glass the shell is wearing, for gg and the tests
        function look(): string {
            return JSON.stringify({ mode: Theme.dark ? "dark" : "light", k: Theme.k, accent: Theme.accentName,
                                    accentColor: String(Theme.accent), glass: Theme.glassMode, clarity: Theme.clarity,
                                    backend: Glass.backend, font: Theme.fontUi });
        }
        // a banner, as the system shows one (gg uses it; so do the tests)
        function banner(title: string, body: string): void { banner.show(title, body); }
    }
}
