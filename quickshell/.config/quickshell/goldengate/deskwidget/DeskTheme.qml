pragma Singleton

import QtQuick
import Quickshell
import qs.common

// The Desk widget in Golden Gate: a thick glass pane (Liquid, Frosted or
// Solid, whatever `gg glass` says), the system's labels and the user's accent.
DeskStyle {
    surface: Theme.glassThick
    surfaceAlt: Theme.fill
    text: Theme.label
    textMuted: Theme.label2
    accent: Theme.accent
    onAccent: Theme.onAccent
    ok: Theme.green
    warn: Theme.orange
    danger: Theme.red
    line: Theme.separator

    fontDisplay: Theme.fontDisplay
    fontBody: Theme.fontUi
    fontMono: Theme.fontMono
    textSize: Theme.textSize
    weight: Font.Normal
    weightStrong: Font.DemiBold

    radius: Theme.radiusPanel
    radiusSmall: Theme.radiusChip + 2
    gap: 10
    barHeight: 32

    glassMode: Theme.glassMode
    backdrop: Component {
        GlassPane {
            thick: true
            radius: Theme.radiusPanel
        }
    }
    namespace: "goldengate:deskpanel"

    durIn: Theme.panelIn
    durOut: Theme.panelOut
    // macOS's ease out for a sheet appearing, its ease in for one leaving
    curveIn: [0.32, 0.72, 0, 1, 1, 1]
    curveOut: [0.4, 0, 1, 1, 1, 1]
    reducedMotion: Theme.reduceMotion
}
