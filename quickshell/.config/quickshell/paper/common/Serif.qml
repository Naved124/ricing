import QtQuick

// Print: Newsreader, for clocks, the calendar's day and song titles.
Text {
    property real size: 18
    property int weight: Theme.weightDisplay

    color: Theme.carbon
    font.family: Theme.fontSerif
    font.pixelSize: size
    font.weight: weight
    font.features: { "tnum": 1 }      // numbers that don't jiggle as they change
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
}
