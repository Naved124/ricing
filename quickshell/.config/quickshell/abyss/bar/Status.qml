pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.common
import qs.services

// The bar's right side, quiet in ink-dim: the network's speed, then the
// network, battery and volume as small marks, and the tray. Hovering one
// drops its detail under the bar (Bar.detail); clicks do what they say.
// While recording, a pink dot pulses first; with caffeine on, a cup.
Row {
    id: root

    required property var bar
    spacing: 10

    // a mark in the bar: an icon and/or a few words; hover shows `detail`
    component Mark: Item {
        id: mark
        property string icon: ""
        property string text: ""
        property string detail: ""
        property color tint: Theme.inkDim
        signal clicked(var mouse)
        signal scrolled(real delta)

        implicitWidth: markRow.implicitWidth
        implicitHeight: 22
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Row {
            id: markRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Icon {
                visible: mark.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: mark.icon
                size: 15
                color: markMouse.containsMouse ? Theme.ink : mark.tint
            }
            Label {
                visible: mark.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: mark.text
                size: 12
                spacing: 0.08
                color: markMouse.containsMouse ? Theme.ink : mark.tint
                font.features: { "tnum": 1 }
            }
        }
        MouseArea {
            id: markMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse && mark.detail) {
                    const p = mark.mapToItem(null, mark.width / 2, 0);
                    root.bar.detail = { x: p.x, text: mark.detail };
                } else if (root.bar.detail?.text === mark.detail) {
                    root.bar.detail = null;
                }
            }
            onClicked: mouse => mark.clicked(mouse)
            onWheel: wheel => mark.scrolled(wheel.angleDelta.y / 120)
        }
    }

    // recording: a pink dot, breathing, and how long
    Mark {
        visible: Shell.recording
        text: Shell.recordingTime
        tint: Theme.pink
        detail: "Recording to ~/Videos · click to stop"
        onClicked: Shell.toggleRecording()
        Rectangle {
            x: -10
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6; radius: 3
            color: Theme.pink
            SequentialAnimation on opacity {
                running: Shell.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }
    }

    Mark {
        visible: Shell.caffeine
        icon: "coffee"
        detail: "Staying awake · click to let it sleep"
        onClicked: Shell.caffeine = false
    }

    // the speed, sampled once a second by one long-lived reader (Net)
    Mark {
        visible: Net.online
        icon: "arrow-down"
        text: Net.rate(Net.down).replace("/s", "")
        detail: `${Net.label}\n↓ ${Net.rate(Net.down)}   ↑ ${Net.rate(Net.up)}`
        onClicked: Shell.toggleCenter()
    }
    Mark {
        visible: !Net.online
        icon: Net.icon
        detail: Net.label
        onClicked: Shell.toggleCenter()
    }

    Mark {
        visible: Battery.present
        icon: Battery.charging ? "bolt" : ""
        text: Math.round(Battery.level * 100) + "%"
        tint: Battery.low ? Theme.pink : Theme.inkDim
        detail: Battery.charging ? "Charging" + (Battery.timeLeft ? ` · full in ${Battery.timeLeft}` : "")
              : Battery.timeLeft ? `${Battery.timeLeft} left` : "On battery"
        onClicked: Shell.toggleCenter()
    }

    Mark {
        icon: Audio.icon
        detail: Audio.muted ? "Muted · click to unmute" : `Volume ${Math.round(Audio.volume * 100)}% · scroll to change`
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) Quickshell.execDetached(["pavucontrol"]);
            else Audio.toggleMute();
        }
        onScrolled: delta => Audio.setVolume(Audio.volume + delta * 0.05)
    }

    // the tray: the apps' own icons, always out
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        visible: SystemTray.items.values.length > 0
        Repeater {
            model: SystemTray.items.values
            delegate: IconImage {
                id: trayIcon
                required property var modelData
                implicitSize: 15
                source: modelData.icon
                anchors.verticalCenter: parent.verticalCenter
                opacity: trayMouse.containsMouse ? 1 : 0.75
                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const item = trayIcon.modelData;
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) {
                                const p = trayIcon.mapToItem(null, 0, trayIcon.height + 14);
                                item.display(root.bar, p.x, p.y);
                            }
                        } else {
                            item.activate();
                        }
                    }
                    onWheel: wheel => trayIcon.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }
}
