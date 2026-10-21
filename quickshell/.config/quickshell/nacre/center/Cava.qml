pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services

// A row of soft bars dancing to whatever is playing, from the shell's one
// cava (services/Beat.qml); quietly absent when cava isn't installed.
Item {
    id: root

    property bool active: false
    readonly property int bars: Beat.bars
    readonly property var levels: active ? Beat.levels : []

    implicitHeight: 34
    visible: levels.length > 0

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Repeater {
            model: root.levels.length
            delegate: Rectangle {
                id: bar
                required property int index
                readonly property real level: root.levels[index] ?? 0
                width: (root.width - (root.bars - 1) * 4) / root.bars
                height: Math.max(width, root.height * level)
                anchors.bottom: parent.bottom
                radius: width / 2
                // the bars walk along the gradient, left to right
                color: Theme.gradient[Math.floor(index / root.bars * (Theme.gradient.length - 1))]
                border.color: Theme.gleamAt(0.4)
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }
}
