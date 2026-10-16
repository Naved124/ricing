import QtQuick
import qs.common
import qs.services

// Network speed, pencilled in: "net ↓ 1.2 MB/s ↑ 40 KB/s", from the one
// long-lived sampler in Net. Each figure keeps a fixed width so the bar
// doesn't shuffle every second. Click for the control centre.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    TextMetrics {
        id: widest
        font.family: Theme.fontHand
        font.pixelSize: 17
        text: "888 KB/s"
    }

    Row {
        id: row
        spacing: 6

        Hand {
            text: "net"
            color: Net.online ? Theme.ink : Theme.red
        }
        Repeater {
            model: [{ arrow: "↓", down: true }, { arrow: "↑", down: false }]
            delegate: Row {
                id: dir
                required property var modelData
                spacing: 2
                Hand {
                    text: dir.modelData.arrow
                    color: Theme.graphite
                }
                Hand {
                    width: Math.ceil(widest.advanceWidth)
                    text: Net.rate(dir.modelData.down ? Net.down : Net.up)
                    color: Theme.ink
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.toggleCenter()
    }
}
