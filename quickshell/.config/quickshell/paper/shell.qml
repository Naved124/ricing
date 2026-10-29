//@ pragma UseQApplication

// Paper — a desk in daylight. Windows are sheets, the terminal is a
// typewriter, notifications are sticky notes unfolding from the bar's
// island, and closing a window crumples it into the bin.
// Run with `qs -c paper` (the `rice` script does this when Paper is active).

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
import qs.osd
import qs.power
import qs.services
import qs.turn
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
    // over the middle of each bar: the time, what's playing, the notes
    Variants {
        model: Quickshell.screens
        Island {}
    }

    // switching workspace turns a page
    Variants {
        model: Quickshell.screens
        PageTurn {}
    }

    // the calendar and the wastebasket, under the windows; the month card
    Desk {}
    // the system card: cpu, memory and disk on a taped index card, draggable
    Stats {}
    Month {}

    // panels that follow the focused monitor
    Launcher {}
    Center {}
    Osd {}
    Power {}
    KeySheet {}
    Lock {}

    // Hyprland binds: hl.dsp.global("quickshell:<name>")
    GlobalShortcut {
        name: "launcher"
        description: "Open the launcher"
        onPressed: Shell.toggleLauncher("")
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
            Shell.toggleLauncher("");
        }
        onPressed: fire()
        onReleased: fire()
    }
    GlobalShortcut {
        name: "clipboard"
        description: "Clipboard history in the launcher"
        onPressed: Shell.toggleLauncher("!")
    }
    GlobalShortcut {
        name: "center"
        description: "Open the control centre"
        onPressed: Shell.toggleCenter()
    }
    GlobalShortcut {
        name: "keybinds"
        description: "Show every key bind"
        onPressed: Shell.toggleKeys()
    }
    GlobalShortcut {
        name: "power"
        description: "Open the power menu"
        onPressed: Shell.togglePower()
    }

    // qs -c paper ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function dnd(on: bool): void { Shell.setDnd(on); }
        function toggleDnd(): void { Shell.setDnd(!Shell.dnd); }
        function recording(on: bool): void { Shell.recording = on; }
        function launcher(mode: string): void { Shell.toggleLauncher(mode); }
        function center(): void { Shell.toggleCenter(); }
        function power(): void { Shell.togglePower(); }
        function keybinds(): void { Shell.toggleKeys(); }
        function caffeine(): void { Shell.caffeine = !Shell.caffeine; }
        function nightLight(on: bool): void { Shell.setNightLight(on); }
        function grain(on: bool): void { Shell.setGrain(on); }
        // open the launcher with text already typed, e.g. "=2^10"
        function search(text: string): void {
            Shell.closeAll();
            Shell.launcherMode = "";
            Shell.launcherText = text;
            Shell.launcherOpen = true;
        }
    }
}
