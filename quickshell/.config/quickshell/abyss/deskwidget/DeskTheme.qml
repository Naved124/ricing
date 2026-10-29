pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.common
import qs.services

// The Desk widget in Abyss: wet glass over the reef, teal for what's alive,
// pink for the alarm. Abyss is always dark.
DeskStyle {
    surface: Theme.glassStrong
    surfaceAlt: Theme.washHover
    text: Theme.ink
    textMuted: Theme.inkDim
    accent: Theme.glow
    onAccent: Theme.abyss
    ok: Theme.success
    warn: Theme.warning
    danger: Theme.pink
    line: Theme.line

    fontDisplay: Theme.fontDisplay
    fontBody: Theme.fontUi
    fontMono: Theme.fontMono
    textSize: Theme.uiSize
    weight: Theme.weight
    weightStrong: Theme.weightStrong

    radius: Theme.radiusPanel
    radiusSmall: Theme.radiusChip
    gap: Theme.gapsOut
    barHeight: 12 + 40

    glassMode: "glass"
    backdrop: Component {
        Glass {
            radius: Theme.radiusPanel
            fill: Theme.glassStrong
        }
    }
    namespace: "abyss-deskpanel"

    durIn: Theme.durPanelIn
    durOut: Theme.durPanelOut
    curveIn: Theme.drift
    curveOut: Theme.sink
    reducedMotion: Motion.reduced
}
