import QtQuick
import qs.common

// Text as the system sets it: SF Pro Text at the body size, in the label
// colour (large type sets font.family: Theme.fontDisplay, as Apple does from 20 pt)
Text {
    property bool strong: false
    property bool secondary: false
    color: secondary ? Theme.label2 : Theme.label
    font.family: Theme.fontUi
    font.pixelSize: Theme.textSize
    font.weight: strong ? Font.DemiBold : Font.Normal
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
