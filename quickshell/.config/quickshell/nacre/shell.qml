//@ pragma UseQApplication

// Nacre — a light desktop, like the inside of a shell.
// Run with `qs -c nacre` (the `rice` script does this when Nacre is active).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs.center
import qs.desk
import qs.keys
import qs.launcher
import qs.lock
import qs.notifs
import qs.osd
import qs.power
import qs.services
import qs.wallpaper

ShellRoot {
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    // the system card: cpu, memory and disk on a pane of glass, draggable
    Stats {}

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // follow the focused monitor
    Popups {}
    Osd {}
    Toast {}
    Flash { id: flasher }
    Launcher {}
    Center {}
    Power {}
    KeySheet {}
    Lock {}

    // Hyprland binds: hl.dsp.global("quickshell:<name>")
    GlobalShortcut {
        name: "launcher"
        description: "Open the launcher"
        onPressed: { Shell.orbScreen = null; Shell.toggleLauncher(""); }
    }
    // Super tapped on its own. Hyprland fires this on release, which some
    // versions report as a press and others as a release, so take whichever
    // comes first and ignore its twin.
    GlobalShortcut {
        id: tap
        name: "launcher-tap"
        description: "Open the launcher (Super on its own)"
        property double last: 0
        function fire() {
            const now = Date.now();
            if (now - last < 250) return;
            last = now;
            Shell.orbScreen = null;
            Shell.toggleLauncher("");
        }
        onPressed: fire()
        onReleased: fire()
    }
    GlobalShortcut {
        name: "keybinds"
        description: "Show every key bind"
        onPressed: Shell.toggleKeys()
    }
    GlobalShortcut {
        name: "center"
        description: "Open the control centre"
        onPressed: Shell.toggleCenter()
    }
    GlobalShortcut {
        name: "power"
        description: "Open the power menu"
        onPressed: Shell.togglePower()
    }
    GlobalShortcut {
        name: "clipboard"
        description: "Open clipboard history in the launcher"
        onPressed: { Shell.orbScreen = null; Shell.toggleLauncher("!"); }
    }

    // qs -c nacre ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function dnd(on: bool): void { Shell.setDnd(on); }
        function toggleDnd(): void { Shell.setDnd(!Shell.dnd); }
        function recording(on: bool): void { Shell.recording = on; }
        function toast(icon: string, text: string): void { Shell.toast(icon, text); }
        function launcher(mode: string): void { Shell.orbScreen = null; Shell.toggleLauncher(mode); }
        function center(focus: string): void { Shell.toggleCenter(focus); }
        function power(): void { Shell.togglePower(); }
        function keybinds(): void { Shell.toggleKeys(); }
        function caffeine(): void { Shell.caffeine = !Shell.caffeine; }
        function flash(): void { flasher.flash(); }
        function nightLight(on: bool): void { Shell.setNightLight(on); }
        // open the launcher with text already typed, e.g. "=2^10" or ":heart"
        function search(text: string): void {
            Shell.orbScreen = null;
            Shell.closeAll();
            Shell.launcherMode = "";
            Shell.launcherText = text;
            Shell.launcherOpen = true;
        }
    }
}
