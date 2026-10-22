pragma ComponentBehavior: Bound

import QtQuick
import qs.common
import qs.services

// The battery as a strip of film: four frames between two rows of sprocket
// holes, exposed (the accent) as far as the charge goes, the last one only
// partly. Charging, the film runs through the gate (a frame every ~1.5 s,
// stepped like a projector); under 20% the last frame flickers in the urgent
// colour. The charge is beside it, with the time left on hover.
Row {
    id: root

    readonly property real level: Battery.level
    readonly property color ink: Battery.low ? Theme.urgent : Theme.accent
    HoverHandler { id: hover }

    spacing: 5

    Item {
        id: film
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 16
        clip: true

        readonly property int frames: 4
        readonly property real fw: width / frames
        // the film running through, a sprocket at a time
        property real run: 0
        Timer {
            interval: 120
            repeat: true
            running: Battery.charging && root.visible && !Motion.reduced
            onTriggered: film.run = (film.run + 1) % Math.round(film.fw)
        }

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Theme.at(Theme.fg, 0.14)
            border.width: 1
            border.color: Theme.at(Theme.fg, 0.35)
        }
        // the frames, exposed as far as the charge goes
        Repeater {
            model: film.frames
            delegate: Item {
                id: frame
                required property int index
                readonly property real f: Math.max(0, Math.min(1, root.level * film.frames - index))
                x: index * film.fw + 1.5
                y: 4
                width: film.fw - 3
                height: film.height - 8
                Rectangle {
                    anchors.fill: parent
                    radius: 1.5
                    color: Theme.at(Theme.fg, 0.08)
                }
                Rectangle {
                    width: parent.width * frame.f
                    height: parent.height
                    radius: 1.5
                    color: root.ink
                    opacity: frame.f >= 1 ? 0.95 : 0.7
                    SequentialAnimation on opacity {
                        running: Battery.low && frame.f > 0 && frame.f < 1
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 500 }
                        NumberAnimation { to: 0.8; duration: 500 }
                    }
                }
            }
        }
        // sprocket holes, top and bottom, moving with the film
        Repeater {
            model: 2
            delegate: Row {
                id: holes
                required property int index
                x: -film.fw + film.run
                y: index === 0 ? 1 : film.height - 3
                spacing: film.fw / 2 - 2
                Repeater {
                    model: film.frames * 2 + 3
                    delegate: Rectangle { width: 2; height: 2; radius: 0.5; color: Theme.at(Theme.ink, 0.7) }
                }
            }
        }
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: hover.hovered && Battery.timeLeft ? Battery.timeLeft : Math.round(root.level * 100) + "%"
        mono: true
        weight: Style.weightStrong
        size: 11.5
        color: Battery.low ? Theme.urgent : Theme.fg
    }
}
