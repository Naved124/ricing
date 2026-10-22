import QtQuick
import QtQuick.Effects
import qs.common

// The accent seal "撮": a rounded square of the plate's accent with the
// character in Dela Gothic One, glowing (the mock's 0 0 16px at 70%).
Item {
    id: root
    property real size: 24
    property real glow: 0.7
    property string glyph: "撮"
    width: size
    height: size

    RectangularShadow {
        anchors.fill: box
        radius: box.radius
        blur: root.size * 0.66
        color: Theme.at(Theme.accent, root.glow)
    }
    Rectangle {
        id: box
        anchors.fill: parent
        radius: root.size / 3
        color: Theme.accent
        Label {
            anchors.centerIn: parent
            text: root.glyph
            display: true
            size: root.size * 0.58
            color: Theme.onAccent
        }
    }
}
