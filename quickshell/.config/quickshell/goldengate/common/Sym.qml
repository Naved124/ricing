import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.common

// A symbol: the icon theme's symbolic icon, drawn in `color` (SF Symbols
// isn't on Linux; MacTahoe's symbolic set stands in). The icon is only a
// mask, so it takes the colour whatever its own fill is (some are black,
// some grey, some unfilled).
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
        implicitSize: root.size
        source: Quickshell.iconPath(root.name, true)
        visible: false
        layer.enabled: true
    }
    Rectangle {
        anchors.fill: parent
        visible: img.source != ""
        color: root.color
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: img
            maskThresholdMin: 0.1
            maskSpreadAtMin: 0.3
        }
    }
}
