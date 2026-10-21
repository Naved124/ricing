pragma ComponentBehavior: Bound

import QtQuick
import qs

// Plankton specks drifting up through a space (the depth gauge's light
// column while it changes, a playing card): a few tiny teal points, each
// rising at its own pace and wavering, fading in and out. Only moves while
// `running`.
Item {
    id: root

    property int count: 10
    property bool running: true
    property color color: Theme.glow
    property real size: 2

    clip: true

    Repeater {
        model: root.count
        delegate: Item {
            id: speck
            required property int index
            readonly property real seed: (index * 0.6180339) % 1
            property real t: seed
            x: root.width * ((seed * 7.3) % 1) + Math.sin(t * 9 + index) * 2
            y: root.height * (1 - t)
            width: root.size
            height: root.size
            opacity: Math.sin(Math.PI * t) * (0.4 + 0.6 * ((seed * 3.7) % 1))

            Rectangle {
                anchors.centerIn: parent
                width: root.size; height: root.size; radius: root.size / 2
                color: root.color
            }
            Glow {
                anchors.centerIn: parent
                width: root.size * 5; height: width
                color: root.color
                opacity: 0.5
            }
            NumberAnimation on t {
                running: root.running && root.visible
                from: 0; to: 1
                loops: Animation.Infinite
                duration: 1600 + speck.seed * 1800
            }
        }
    }
}
