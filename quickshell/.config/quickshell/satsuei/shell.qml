//@ pragma UseQApplication

// Satsuei (撮影) — light, composited over your wallpaper. Dark only.
// The plate is the user's picture, the pass a shader that adds its light,
// and the cels (the bar, the drawers, the subtitles) are glass whose every
// colour comes from the plate (common/Theme.qml, from satsuei-wall).
// Run with `qs -c satsuei` (the `rice` script does this when Satsuei is active).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs.cast
import qs.center
import qs.chars
import qs.common
import qs.desk
import qs.keys
import qs.launcher
import qs.lock
import qs.mascot
import qs.osd
import qs.panel
import qs.plate
import qs.power
import qs.services
import qs.subs
import qs.walls

ShellRoot {
    // the plate and its pass, one per screen, under everything
    Variants {
        model: Quickshell.screens
        Plate {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Variants {
        model: Quickshell.screens
        Eyecatch {}
    }

    // follow the focused monitor
    Center {}
    Stats {}
    Subtitles {}
    Osd {}
    Toast {}
    Launcher {}
    Power {}
    KeySheet {}
    Cast {}
    Selector {}
    Studio {}
    Mascot {}
    Lock {}

    // Hyprland binds: hl.dsp.global("quickshell:<name>"), the same in every rice
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
    // Satsuei's own (base.lua binds them; only this shell registers them)
    GlobalShortcut {
        name: "satsuei-walls"
        description: "Choose the wallpaper"
        onPressed: Shell.toggleWalls()
    }
    GlobalShortcut {
        name: "satsuei-cast"
        description: "Choose the characters"
        onPressed: Shell.toggleCast()
    }
    GlobalShortcut {
        name: "satsuei-dancer-next"
        description: "The next character as the dancer"
        onPressed: Shell.toast("person", `Dancer: ${Characters.byId(Characters.next("dancer")).name}`)
    }
    GlobalShortcut {
        name: "satsuei-mascot-next"
        description: "The next character as the edge mascot"
        onPressed: Shell.toast("person", `Mascot: ${Characters.byId(Characters.next("mascot")).name}`)
    }
    GlobalShortcut {
        name: "clipboard"
        description: "Open clipboard history in the launcher"
        onPressed: Shell.toggleLauncher("!")
    }

    // qs -c satsuei ipc call shell <function> [args]
    IpcHandler {
        target: "shell"
        function dnd(on: bool): void { Shell.setDnd(on); }
        function toggleDnd(): void { Shell.setDnd(!Shell.dnd); }
        function recording(on: bool): void { Shell.recording = on; }
        function toast(icon: string, text: string): void { Shell.toast(icon, text); }
        function launcher(mode: string): void { Shell.toggleLauncher(mode); }
        function center(focus: string): void { Shell.toggleCenter(focus); }
        function studio(): void { Shell.toggleStudio(); }
        function power(): void { Shell.togglePower(); }
        function keybinds(): void { Shell.toggleKeys(); }
        function caffeine(): void { Shell.caffeine = !Shell.caffeine; }
        function nightLight(on: bool): void { Shell.setNightLight(on); }
        function search(text: string): void {
            Shell.closeAll();
            Shell.launcherMode = "";
            Shell.launcherText = text;
            Shell.launcherOpen = true;
        }
    }

    // qs -c satsuei ipc call satsuei <function> [args]
    IpcHandler {
        target: "satsuei"
        // the tokens on screen now, as JSON
        function theme(): string { return JSON.stringify(Theme.t, null, 2); }
        // every screen's pass: running or paused and why, fps, the effects
        function stats(): string { return JSON.stringify(Plates.stats(), null, 2); }
        // the pass's switches: bloom, rays, motes, grain, grade, pass (compositing)
        function fx(name: string, on: bool): void { Settings.setFx(name, on); }
        function toggleFx(name: string): void { Settings.setFx(name, !Settings.fx(name)); }
        // who plays the dancer (the media card) or the mascot (the screen edge)
        function setCharacter(role: string, id: string): string {
            return Characters.set(role, id) ? id : `no character called ${id}`;
        }
        function nextCharacter(role: string): string { return Characters.next(role); }
        // the wallpaper: open (the selector), next, prev or random from what
        // it shows; setWallpaper for a file
        function wallpaper(action: string): string {
            if (action === "open") { Shell.toggleWalls(); return "open"; }
            if (action === "next") return Library.step(1) || "nothing to show";
            if (action === "prev") return Library.step(-1) || "nothing to show";
            if (action === "random") return Library.random() || "nothing to show";
            return `don't know ${action} (open, next, prev, random)`;
        }
        function setWallpaper(path: string): void { Library.apply(path); }
        // the Cast picker, casting for a role (dancer or mascot)
        function cast(role: string): void { Shell.toggleCast(role || undefined); }
        // a test subtitle (the mock's "Send a test")
        function testNote(): void {
            Quickshell.execDetached(["notify-send", "-a", "Calendar", "Study block starts in 10 minutes."]);
        }
        // hold the hour (0–24), or follow the clock again with a negative one
        function hour(h: real): void {
            if (h < 0) { Settings.s.follow = true; return; }
            Settings.s.follow = false;
            Settings.s.hour = h % 24;
        }
    }
}
