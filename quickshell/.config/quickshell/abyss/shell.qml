//@ pragma UseQApplication

// Abyss — a night dive on a reef. Dark only.
// Run with `qs -c abyss` (the `rice` script does this when Abyss is active).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.reef
import qs.services

ShellRoot {
    // the reef, one per screen, under everything
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }
    Variants {
        model: Quickshell.screens
        StatsOverlay {}
    }

    // Hyprland binds: hl.dsp.global("quickshell:<name>")
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
            if (s) Reefs.notify(s, s.width / 2, 24);
        }
    }

    // qs -c abyss ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function toast(icon: string, text: string): void { Shell.toast(icon, text); }
        function recording(on: bool): void { Shell.recording = on; }
        function dnd(on: bool): void { Shell.setDnd(on); }
        function toggleDnd(): void { Shell.setDnd(!Shell.dnd); }
    }
}
