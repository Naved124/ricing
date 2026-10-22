//@ pragma UseQApplication

// Satsuei (撮影) — light, composited over your wallpaper. Dark only.
// The plate is the user's picture, the pass a shader that adds its light,
// and the cels (the bar, the drawers, the subtitles) are glass whose every
// colour comes from the plate (common/Theme.qml, from satsuei-wall).
// Run with `qs -c satsuei` (the `rice` script does this when Satsuei is active).

import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
import qs.center
import qs.common
import qs.plate
import qs.services
import qs.subs

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

    Center {}
    Subtitles {}

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
        // hold the hour (0–24), or follow the clock again with a negative one
        // a test subtitle (the mock's "Send a test")
        function testNote(): void {
            Quickshell.execDetached(["notify-send", "-a", "Calendar", "Study block starts in 10 minutes."]);
        }
        function hour(h: real): void {
            if (h < 0) { Settings.s.follow = true; return; }
            Settings.s.follow = false;
            Settings.s.hour = h % 24;
        }
    }
}
