import QtQuick
import qs.common
import qs.services

// The volume as a pencil speaker (crossed out when muted). Click for the
// control centre, scroll to change the volume (up to 150%), middle-click
// to mute.
Item {
    id: root

    implicitWidth: 24
    implicitHeight: 24

    Glyph {
        anchors.centerIn: parent
        name: Audio.muted || Audio.volume <= 0.001 ? "speaker-off" : "speaker"
        size: 22
        color: Audio.muted ? Theme.graphite : Theme.ink
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) Audio.toggleMute();
            else Shell.toggleCenter();
        }
        onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
