import QtQuick
import Quickshell

// What the Desk widget asks of a rice. The widget has no colour, font,
// radius, blur or timing of its own: each shell's DeskTheme (a singleton made
// of this) fills every property below from that rice's Theme, so a switch
// restyles it and nothing else changes. tests/test_desk_widget.py checks
// that every DeskTheme sets them all.
Singleton {
    // colours
    property color surface         // the panel's fill when it is solid
    property color surfaceAlt      // rows, chips, the tab strip
    property color text
    property color textMuted
    property color accent
    property color onAccent        // text on an accent fill
    property color ok
    property color warn
    property color danger
    property color line            // hairlines and checkbox edges

    // type
    property string fontDisplay
    property string fontBody
    property string fontMono
    property real textSize
    property int weight
    property int weightStrong

    // shape
    property real radius           // the panel
    property real radiusSmall      // rows, chips, the input
    property real gap              // from the screen's edge
    property real barHeight        // where the panel and the capture line hang from

    // glass: "solid", "glass" (Hyprland's blur behind the rice's own pane) or
    // "liquid" (Golden Gate's); `backdrop` is the rice's own pane, drawn
    // under the panel, or null for a plain `surface` fill
    property string glassMode
    property Component backdrop
    property string namespace      // the layer's name, for the rice's blur rule

    // motion: the rice's panel timings and curves; reducedMotion fades only
    property int durIn
    property int durOut
    property var curveIn
    property var curveOut
    property bool reducedMotion
}
