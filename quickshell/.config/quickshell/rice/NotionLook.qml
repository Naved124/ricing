pragma Singleton

import QtQuick
import Quickshell

// The Notion widget's dress: the active rice's fonts, corners and roles
// (mixed by the mode through Theme), as the network widget wears them.
Singleton {
    readonly property var meta: Rices.active?.meta ?? ({})
    readonly property string fontUi: meta.fonts?.ui ?? "sans-serif"
    readonly property string fontDisplay: meta.fonts?.display ?? fontUi
    readonly property string fontMono: meta.fonts?.mono ?? "monospace"
    readonly property real uiSize: meta.fonts?.ui_size ?? 14
    readonly property int weight: meta.fonts?.weight ?? 500
    readonly property int strong: meta.fonts?.weight_strong ?? 700
    readonly property real radius: meta.shape?.panel ?? 14
    readonly property real chip: meta.shape?.chip ?? 8
    readonly property var bloom: meta.motion?.bloom ?? [0.2, 0.9, 0.2, 1.0]
    function role(n) { return Theme.role(n); }
    // a role as text: half of it over fg, so pastels read on light glass
    function ink(n) { return n === "muted" ? role("fg") : Qt.tint(role("fg"), Qt.alpha(role(n), 0.55)); }
    // text on a fill: fg, or bg where fg would be too faint on it
    function on(fill) {
        const l = c => { const x = Qt.color(c); return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b; };
        const f = role("fg"), b = role("bg"), y = l(fill);
        return Math.abs(l(f) - y) >= Math.abs(l(b) - y) ? f : b;
    }
}
