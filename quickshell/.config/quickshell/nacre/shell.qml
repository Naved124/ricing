//@ pragma UseQApplication

// Nacre — a light desktop, like the inside of a shell.
// Run with `qs -c nacre` (the `rice` script does this when Nacre is active).

import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
import qs.notifs
import qs.osd
import qs.services
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

    // follow the focused monitor
    Popups {}
    Osd {}
    Toast { id: toaster }

    // qs -c nacre ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function dnd(on: bool): void { Shell.setDnd(on); }
        function toggleDnd(): void { Shell.setDnd(!Shell.dnd); }
        function recording(on: bool): void { Shell.recording = on; }
        function toast(icon: string, text: string): void { toaster.show(icon, text); }
    }
}
