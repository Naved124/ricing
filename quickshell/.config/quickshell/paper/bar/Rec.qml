import QtQuick
import qs.common
import qs.services

// While recording: a red ink dot and the running time, written by hand.
// Click to stop. Hidden the rest of the time.
Item {
    id: root

    visible: Shell.recording
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10
            radius: 5
            color: Theme.red
            SequentialAnimation on opacity {
                running: root.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        Hand {
            anchors.verticalCenter: parent.verticalCenter
            text: `rec ${Shell.recordingTime}`
            color: Theme.red
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.toggleRecording()
    }
}
