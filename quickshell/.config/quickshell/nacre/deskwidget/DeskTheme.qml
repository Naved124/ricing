pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.common

// The Desk widget in Nacre: frosted glass, ink on pearl, plum where it
// points at something (the pastels are too pale to read as text by day).
DeskStyle {
    surface: Theme.glassStrong
    surfaceAlt: Theme.glassSoft
    text: Theme.ink
    textMuted: Theme.inkSoft
    accent: Theme.c("plum")
    onAccent: Theme.pearl
    ok: Theme.dark ? Theme.mint : Qt.darker(Theme.mint, 1.9)
    warn: Theme.dark ? Theme.sun : Qt.darker(Theme.sun, 2.4)
    danger: Theme.dark ? Theme.alert : Qt.darker(Theme.alert, 1.8)
    line: Theme.hairline

    fontDisplay: Theme.fontDisplay
    fontBody: Theme.fontUi
    fontMono: Theme.fontMono
    textSize: Theme.uiSize
    weight: Theme.weight
    weightStrong: Theme.weightStrong

    radius: Theme.radiusPanel + 6
    radiusSmall: Theme.radiusChip + 2
    gap: Theme.gapsOut
    barHeight: 12 + 38

    glassMode: "glass"
    backdrop: Component {
        Glass {
            radius: Theme.radiusPanel + 6
            fill: Theme.glassStrong
        }
    }
    namespace: "nacre-desk"

    durIn: Theme.durPanelIn
    durOut: Theme.durPanelOut
    curveIn: Theme.bloom
    curveOut: Theme.sink
    reducedMotion: Quickshell.env("RICE_REDUCED_MOTION") === "1"
}
