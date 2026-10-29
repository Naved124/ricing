pragma Singleton

import QtQuick
import Quickshell
import qs.common

// The Desk (card, full view, capture) in Paper: a sheet of card stock with a torn edge, typed in
// ink, the red pen for what points at something, kraft for the rows.
DeskStyle {
    surface: Theme.card
    surfaceAlt: Qt.alpha(Theme.kraft, Theme.dark ? 0.35 : 0.28)
    text: Theme.ink
    textMuted: Theme.pencil
    accent: Theme.red
    onAccent: Theme.card
    ok: Theme.fern
    warn: Theme.ochre
    danger: Theme.red
    line: Theme.rule

    fontDisplay: Theme.fontDisplay
    fontBody: Theme.fontType
    fontMono: Theme.fontType
    textSize: Theme.uiSize
    weight: Theme.weight
    weightStrong: Theme.weightStrong

    radius: Theme.radiusPanel
    radiusSmall: Theme.radiusChip + 2
    gap: Theme.gapsOut
    barHeight: 10 + 44

    glassMode: "solid"
    backdrop: Component {
        Sheet {
            seed: 11
        }
    }
    namespace: "paper-deskpanel"
    cardBackdrop: Component {
        Sheet {
            seed: 7
        }
    }
    cardNamespace: "paper-deskcard"

    durIn: Theme.durPanelIn
    durOut: Theme.durPanelOut
    curveIn: Theme.drop
    curveOut: Theme.toss
    reducedMotion: Quickshell.env("RICE_REDUCED_MOTION") === "1"
}
