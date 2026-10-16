import QtQuick
import Quickshell
import qs
import qs.common
import qs.services

// Network, volume, battery and the system tray. Hovering any chip opens it.
Row {
    id: root

    required property var bar

    spacing: 2

    Chip {
        icon: Net.icon
        label: Net.label
        onClicked: Shell.toggleCenter()
    }

    Chip {
        icon: Audio.icon
        label: Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) Quickshell.execDetached(["pavucontrol"]);
            else Audio.toggleMute();
        }
        onScrolled: delta => Audio.setVolume(Audio.volume + delta * 0.05)
    }

    // battery: an outline with an iridescent fill, sun-yellow below 20%
    Chip {
        visible: Battery.present
        label: Math.round(Battery.level * 100) + "%" + (Battery.charging ? " · charging" : Battery.timeLeft ? " · " + Battery.timeLeft : "")
        onClicked: Shell.toggleCenter()

        Item {
            width: 24
            height: 18

            Rectangle {
                id: shellOutline
                x: 0; y: 4
                width: 21; height: 11
                radius: 3.5
                color: "transparent"
                border.color: Battery.low ? Qt.darker(Theme.sun, 1.6) : Theme.ink
                border.width: 1.4
            }
            Rectangle {
                x: 21.5; y: 7.5
                width: 2; height: 4
                radius: 1
                color: shellOutline.border.color
            }
            Item {
                x: 2.5; y: 6.5
                width: Math.max(2, 16 * Battery.level)
                height: 6
                Behavior on width { NumberAnimation { duration: 600 } }

                Iridescent {
                    anchors.fill: parent
                    radius: 2
                    visible: !Battery.low
                    period: 14000
                    sheen: 0
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    visible: Battery.low
                    color: Theme.sun
                }
            }
            Icon {
                visible: Battery.charging
                x: 6; y: 3
                name: "bolt"
                size: 12
                stroke: 2.2
                color: Theme.ink
            }
        }
    }

    Tray {
        bar: root.bar
    }
}
