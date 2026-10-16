import QtQuick

// Typewriter: Courier Prime, carbon ink.
Text {
    property real size: 14
    property int weight: 400          // 400 or 700

    color: Theme.carbon
    font.family: Theme.fontType
    font.pixelSize: size
    font.weight: weight
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
}
