import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.common

// A symbol: the icon theme's symbolic icon, drawn in `color` (SF Symbols
// isn't on Linux; MacTahoe's symbolic set stands in)
Item {
    id: root
    property string name: ""
    property color color: Theme.label
    property real size: 16
    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        anchors.fill: parent
        source: Quickshell.iconPath(root.name, true)
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        colorization: 1
        colorizationColor: root.color
        brightness: 1
    }
}
