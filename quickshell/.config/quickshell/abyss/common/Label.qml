import QtQuick
import qs

// Text in Abyss's face (Jura), pale sea-glass ink.
Text {
    property real size: Theme.uiSize
    property int weight: Theme.weight
    // Jura reads best spaced out; small caps-like labels take more
    property real spacing: 0.04

    color: Theme.ink
    font.family: Theme.fontUi
    font.pixelSize: size
    font.weight: weight
    font.letterSpacing: size * spacing
    verticalAlignment: Text.AlignVCenter
}
