import QtQuick

// Handwriting: Kalam, in pencil unless told otherwise.
Text {
    property real size: 17
    property int weight: 400          // Kalam comes in 300, 400 and 700

    color: Theme.pencil
    font.family: Theme.fontHand
    font.pixelSize: size
    font.weight: weight
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
}
