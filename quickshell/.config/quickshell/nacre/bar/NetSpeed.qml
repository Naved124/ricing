import QtQuick
import qs
import qs.common
import qs.services

// Live network speed: down and up, summed over the physical links, updated
// once a second. Each figure sits right after its arrow in a box as wide as
// the widest figure ("999 KB/s"), so the bar doesn't jitter as they change.
Row {
    id: root

    visible: Net.online
    spacing: 8

    TextMetrics {
        id: widest
        text: "999 KB/s"
        font.family: Theme.fontMono
        font.weight: Theme.weight
        font.pixelSize: Theme.uiSize + 0.5
    }

    Repeater {
        model: [
            { icon: "arrow-down", down: true },
            { icon: "arrow-up", down: false },
        ]

        delegate: Row {
            id: dir
            required property var modelData
            spacing: 2

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: dir.modelData.icon
                size: 12
                stroke: 2
                color: Theme.inkSoft
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: widest.advanceWidth
                text: Net.rate(dir.modelData.down ? Net.down : Net.up)
                color: Theme.ink
                font.family: Theme.fontMono
                font.weight: Theme.weight
                font.pixelSize: Theme.uiSize + 0.5
            }
        }
    }
}
