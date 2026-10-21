import QtQuick
import QtQuick.Effects
import qs

// Wet glass floating in the water: a dark fill Hyprland blurs the reef
// behind (glass, 70%, or glassStrong, 86%), a faint teal line round its
// edge, a hair of light along the top inside edge, and a faint teal halo
// in the water around it (the mock's 0 0 28px at 5%). `deep` adds the
// heavy shadow a window has.
Item {
    id: root

    property real radius: Theme.radiusPanel
    property color fill: Theme.glass
    property color line: Theme.line
    property real halo: 0.05
    property bool deep: false
    default property alias content: inner.data

    RectangularShadow {
        anchors.fill: plate
        visible: root.deep
        radius: root.radius
        offset.y: 18
        blur: 50
        color: Qt.alpha(Theme.shadow, 0.55)
    }
    RectangularShadow {
        anchors.fill: plate
        visible: root.halo > 0
        radius: root.radius
        blur: 28
        color: Theme.glowAt(root.halo)
    }
    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.color: root.line
        border.width: 1
    }
    // the inset lip: 1 px of light just inside the top edge
    Rectangle {
        x: root.radius * 0.6
        y: 1
        width: Math.max(0, parent.width - root.radius * 1.2)
        height: 1
        color: Theme.inkAt(0.035)
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
