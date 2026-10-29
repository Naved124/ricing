pragma Singleton

import QtQuick
import Quickshell
import qs.common
import qs.services

// The Desk widget in Satsuei: the cel layer's glass, its colours taken from
// the wallpaper (theme.json) like every other panel, so it follows the plate.
DeskStyle {
    surface: Theme.glassDeep
    surfaceAlt: Theme.tile
    text: Theme.fg
    textMuted: Theme.fgDim
    accent: Theme.accent
    onAccent: Theme.onAccent
    ok: Theme.success
    warn: Theme.warning
    danger: Theme.urgent
    line: Theme.rim

    fontDisplay: Style.fontDisplay
    fontBody: Style.fontUi
    fontMono: Style.fontMono
    textSize: Style.uiSize
    weight: Style.weight
    weightStrong: Style.weightStrong

    radius: Style.radiusPanel
    radiusSmall: Style.radiusChip
    gap: Style.gapsOut
    barHeight: 10 + 46

    glassMode: "glass"
    backdrop: Component {
        Glass {
            radius: Style.radiusPanel
            fill: Theme.glassDeep     // a menu's glass: the timesheet mustn't read through
        }
    }
    namespace: "satsuei-deskpanel"

    durIn: Style.durPanelIn
    durOut: Style.durPanelOut
    curveIn: Style.bloom
    curveOut: Style.sink
    reducedMotion: Motion.reduced
}
