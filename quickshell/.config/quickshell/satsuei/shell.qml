//@ pragma UseQApplication

// Satsuei (撮影) — light, composited over your wallpaper. Dark only.
// The plate is the user's picture, the pass a shader that adds its light,
// and the cels (the bar, the drawers, the subtitles) are glass whose every
// colour comes from the plate (common/Theme.qml, from satsuei-wall).
// Run with `qs -c satsuei` (the `rice` script does this when Satsuei is active).

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

ShellRoot {
    // qs -c satsuei ipc call satsuei <function> [args]
    IpcHandler {
        target: "satsuei"
        // the tokens on screen now, as JSON
        function theme(): string { return JSON.stringify(Theme.t, null, 2); }
    }
}
