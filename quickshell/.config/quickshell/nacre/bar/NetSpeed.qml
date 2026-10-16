import QtQuick
import qs
import qs.common
import qs.services

// Live network speed: down and up, summed over the physical links, updated
// once a second. Fixed-width figures so the bar doesn't jitter as they change.
Row {
    id: root

    visible: Net.online
    spacing: 10

    TextMetrics {
        id: widest
        text: "999.9 KB/s"
        font.family: Theme.fontMono
        font.pixelSize: Theme.uiSize + 0.5
    }

    Repeater {
        model: [
            { icon: "arrow-down", value: () => Net.down },
            { icon: "arrow-up", value: () => Net.up },
        ]

        delegate: Row {
            id: dir
            required property var modelData
            spacing: 3

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
                horizontalAlignment: Text.AlignRight
                text: Net.rate(dir.modelData.value())
                color: Theme.ink
                font.family: Theme.fontMono
                font.pixelSize: Theme.uiSize + 0.5
            }
        }
    }
}
