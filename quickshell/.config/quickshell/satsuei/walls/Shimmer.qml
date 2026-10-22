import QtQuick
import qs.common

// A picture still being read: a pale band sweeping across, only while shown.
Item {
    id: root
    clip: true
    Rectangle { anchors.fill: parent; color: Theme.tile }
    Rectangle {
        id: band
        width: root.width * 0.5
        height: root.height * 2
        y: -root.height / 2
        rotation: 18
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.at(Theme.fg, 0) }
            GradientStop { position: 0.5; color: Theme.at(Theme.fg, 0.12) }
            GradientStop { position: 1; color: Theme.at(Theme.fg, 0) }
        }
        NumberAnimation on x {
            from: -root.width * 0.6
            to: root.width * 1.1
            duration: 1300
            loops: Animation.Infinite
            running: root.visible
        }
    }
}
