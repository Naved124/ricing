//@ pragma UseQApplication

// Nacre — a light desktop, like the inside of a shell.
// Run with `qs -c nacre` (the `rice` script does this when Nacre is active).

import QtQuick
import Quickshell
import qs.bar
import qs.wallpaper

ShellRoot {
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }
}
