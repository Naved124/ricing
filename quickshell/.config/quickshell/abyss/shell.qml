//@ pragma UseQApplication

// Abyss — a night dive on a reef. Dark only. The desktop is deep water and
// the UI is glass floating in it; everything that glows is alive, and every
// touch is a disturbance in the water.
// Run with `qs -c abyss` (the `rice` script does this when Abyss is active).

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
import qs.reef
import qs.services

ShellRoot {
    // the reef, one per screen, under everything
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    // the system card: a jellyfish on the desktop
    Stats {}

    Variants {
        model: Quickshell.screens
        Bar {}
    }
    // over the middle of each bar: the time, what's playing, notifications
    Variants {
        model: Quickshell.screens
        Island {}
    }
    Variants {
        model: Quickshell.screens
        StatsOverlay {}
    }

    // follow the focused monitor
    Osd {}
    Toast {}
    Launcher {}
    Center {}
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
        onPressed: Shell.toggleLauncher("!")
    }
    GlobalShortcut {
        name: "reef-interactive"
        description: "Let the reef feel the pointer, or not"
        onPressed: Shell.setReefInteractive(!Shell.reefInteractive)
    }
    GlobalShortcut {
        name: "reef-stats"
        description: "Show the reef's stats"
        onPressed: Shell.reefStats = !Shell.reefStats
    }

    // qs -c abyss ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function dnd(on: bool): void { Shell.setDnd(on); }
        function toggleDnd(): void { Shell.setDnd(!Shell.dnd); }
        function recording(on: bool): void { Shell.recording = on; }
        function toast(icon: string, text: string): void { Shell.toast(icon, text); }
        function launcher(mode: string): void { Shell.toggleLauncher(mode); }
        function center(focus: string): void { Shell.toggleCenter(focus); }
        function power(): void { Shell.togglePower(); }
        function keybinds(): void { Shell.toggleKeys(); }
        function caffeine(): void { Shell.caffeine = !Shell.caffeine; }
        function nightLight(on: bool): void { Shell.setNightLight(on); }
        // open the launcher with text already typed, e.g. "=2^10" or ":heart"
        function search(text: string): void {
            Shell.closeAll();
            Shell.launcherMode = "";
            Shell.launcherText = text;
            Shell.launcherOpen = true;
        }
    }

    // qs -c abyss ipc call reef <function> [args]
    IpcHandler {
        target: "reef"
        // every screen's numbers, as JSON: fps, ms a frame, sizes, counts, throttle
        function stats(): string { return JSON.stringify(Reefs.stats(), null, 2); }
        function interactive(on: bool): void { Shell.setReefInteractive(on); }
        function toggleInteractive(): void { Shell.setReefInteractive(!Shell.reefInteractive); }
        function toggleStats(): void { Shell.reefStats = !Shell.reefStats; }
        // touch the water on the focused screen (x, y in its px; strength 0..1)
        function disturb(x: real, y: real, strength: real): void { Reefs.disturb(Hypr.focusedScreen, x, y, strength); }
        // a notification's flare, under the island
        function notify(): void {
            const s = Hypr.focusedScreen;
            if (s) Reefs.notify(s, s.width / 2, 34);
        }
    }
}
