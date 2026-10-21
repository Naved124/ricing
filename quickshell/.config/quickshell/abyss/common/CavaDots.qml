pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services

// The music as plankton: one glowing dot a band (from the shell's one cava,
// Beat.levels), lifted by its level and brighter with it, a fainter one
// trailing under it. Flat and dim when nothing plays or cava is missing.
Row {
    id: root

    property int count: 24
    property real tall: 28
    property real dot: 3

    spacing: Math.max(2, dot)
    height: tall

    Repeater {
        model: root.count
        delegate: Item {
            id: band
            required property int index
            readonly property real level: Beat.levels[Math.floor(index * Beat.bars / root.count)] ?? 0
            property real shown: level
            Behavior on shown { NumberAnimation { duration: 80 } }
            width: root.dot
            height: root.tall

            // the trail
            Rectangle {
                x: (root.dot - width) / 2
                y: (root.tall - root.dot) * (1 - band.shown * 0.6)
                width: root.dot * 0.6; height: width; radius: width / 2
                color: Theme.glow
                opacity: 0.15 + 0.25 * band.shown
            }
            Glow {
                anchors.centerIn: head
                width: root.dot * (3 + 4 * band.shown); height: width
                color: band.index % 5 === 3 ? Theme.glow2 : Theme.glow
                opacity: 0.25 + 0.6 * band.shown
            }
            Rectangle {
                id: head
                y: (root.tall - root.dot) * (1 - band.shown)
                width: root.dot; height: root.dot; radius: root.dot / 2
                color: Theme.ink
                opacity: 0.35 + 0.65 * band.shown
            }
        }
    }
}
