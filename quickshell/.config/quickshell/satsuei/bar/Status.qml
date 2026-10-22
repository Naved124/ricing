pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.services

// The bar's right side, as the mock has it: what's playing in a sunken pill
// with a 4-bar equaliser from cava, then Wi-Fi (and its speed, from one
// long-lived reader), Bluetooth, volume and the battery (Reel: a strip of
// film), the apps' tray, the lock and the control centre. While recording, an
// accent dot and the time come first; with caffeine on, a cup.
Row {
    id: root

    required property var bar
    spacing: 6

    // what's playing: the equaliser and the title, a click opens the centre
    Rectangle {
        id: mini
        visible: !!Media.player && (Media.player.trackTitle ?? "") !== ""
        anchors.verticalCenter: parent.verticalCenter
        height: 32
        width: Math.min(240, miniRow.implicitWidth + 24)
        radius: 11
        color: miniMouse.containsMouse ? Theme.hover : Theme.well
        Row {
            id: miniRow
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: 14
                spacing: 2
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        // four bands spread over the 30: bass to treble
                        readonly property real v: Media.playing ? (Beat.levels[[1, 6, 13, 21][index]] ?? 0) : 0
                        anchors.bottom: parent.bottom
                        width: 3
                        radius: 2
                        height: 14 * (0.25 + 0.75 * Math.min(1, v * 1.4))
                        color: Theme.accent
                        Behavior on height { NumberAnimation { duration: 90 } }
                    }
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 196)
                elide: Text.ElideRight
                text: (Media.player?.trackTitle ?? "") + (Media.player?.trackArtist ? " — " + Media.player.trackArtist : "")
                size: 12.5
                weight: 500
            }
        }
        MouseArea {
            id: miniMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => mouse.button === Qt.MiddleButton ? Media.player?.togglePlaying() : Shell.toggleCenter()
        }
    }

    // recording: an accent dot, breathing, and how long
    Btn {
        visible: Shell.recording
        anchors.verticalCenter: parent.verticalCenter
        height: 32
        width: recRow.implicitWidth + 16
        onClicked: Shell.toggleRecording()
        Row {
            id: recRow
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 3.5
                color: Theme.urgent
                SequentialAnimation on opacity {
                    running: Shell.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }
            Label { text: Shell.recordingTime; mono: true; size: 11.5; color: Theme.urgent }
        }
    }
    Btn {
        visible: Shell.caffeine
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32
        onClicked: Shell.caffeine = false
        Icon { anchors.centerIn: parent; name: "coffee"; color: Theme.accent }
    }

    // the tray of marks: Wi-Fi and its speed, Bluetooth, volume, battery
    Btn {
        anchors.verticalCenter: parent.verticalCenter
        height: 32
        width: marks.implicitWidth + 20
        onClicked: Shell.toggleCenter()
        onScrolled: delta => Audio.setVolume(Audio.volume + delta * 0.05)
        Row {
            id: marks
            anchors.centerIn: parent
            spacing: 10
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Icon { anchors.verticalCenter: parent.verticalCenter; name: Net.icon; color: Theme.fg }
                Label {
                    visible: Net.online
                    anchors.verticalCenter: parent.verticalCenter
                    text: Net.rate(Net.down).replace("/s", "")
                    mono: true
                    size: 10.5
                    color: Theme.fgDim
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Bluetooth.defaultAdapter?.enabled ? "bluetooth" : "bluetooth-off"
                color: Theme.fg
            }
            Icon { anchors.verticalCenter: parent.verticalCenter; name: Audio.icon; color: Theme.fg }
            Reel {
                visible: Battery.present
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // the apps' own tray icons
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
                opacity: trayMouse.containsMouse ? 1 : 0.8
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

    Btn {
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32
        onClicked: Quickshell.execDetached(["rice", "lock"])
        Icon { anchors.centerIn: parent; name: "lock"; color: Theme.fg }
    }
    Btn {
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32
        on: Shell.centerOpen
        onClicked: Shell.toggleCenter()
        Icon { anchors.centerIn: parent; name: "sliders"; color: Theme.fg }
    }
}
