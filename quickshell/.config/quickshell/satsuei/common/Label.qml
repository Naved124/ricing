import QtQuick

// Text in Satsuei's face (M PLUS Rounded 1c); `display` for Dela Gothic One,
// `mono` for JetBrains Mono (numbers).
Text {
    property real size: 13
    property int weight: Style.weight
    property real spacing: 0
    property bool display: false
    property bool mono: false

    color: Theme.fg
    font.family: display ? Style.fontDisplay : mono ? Style.fontMono : Style.fontUi
    font.pixelSize: size
    font.weight: display ? Style.weightDisplay : weight
    font.letterSpacing: size * spacing
    verticalAlignment: Text.AlignVCenter
}
