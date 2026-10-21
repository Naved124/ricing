pragma Singleton

import QtQuick
import Quickshell

// The chooser's own colours: the active rice's roles in both modes (from its
// rendered meta.json), mixed by k the way the rices' own shells mix theirs.
// Not generated, since the chooser outlives rice switches; it holds no
// colours of its own.
Singleton {
    id: root

    readonly property var modes: Rices.active?.meta?.modes ?? null

    // the active rice's bloom curve, as Easing.BezierSpline control points
    readonly property Mode mode: Mode {
        curve: (Rices.active?.meta?.motion?.bloom ?? [0.2, 0.9, 0.2, 1.0]).concat([1, 1])
    }
    readonly property bool dark: mode.dark
    readonly property real k: mode.k

    // a role of the active rice; before the first render, nothing shows
    function role(name) {
        const l = modes?.light?.roles?.[name];
        return l ? mode.mix(l, modes?.dark?.roles?.[name] ?? l) : "transparent";
    }
}
