import QtQuick
import qs

// Text in Nacre's UI face.
Text {
    property real size: Theme.uiSize + 2
    property int weight: Font.Medium

    color: Theme.ink
    font.family: Theme.fontUi
    font.pixelSize: size
    font.weight: weight
    verticalAlignment: Text.AlignVCenter
}
