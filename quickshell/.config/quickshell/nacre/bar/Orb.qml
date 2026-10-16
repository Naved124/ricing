import QtQuick
import Quickshell
import qs
import qs.common
import qs.services

// The orb: a rotating iridescent pearl. Click opens the launcher (which
// blooms out of here); right-click opens the rice chooser.
// A moon means Do Not Disturb; a pulsing rose dot means the screen is
// being recorded.
Item {
    id: root

    required property var bar

    implicitWidth: 26
    implicitHeight: 26
    scale: mouse.containsMouse ? 1.08 : 1
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

    Iridescent {
        anchors.fill: parent
        radius: width / 2
        period: 9000
        sheen: 0.45
    }

    // the pearl's highlight
    Rectangle {
        x: 6; y: 5
        width: 8; height: 6
        radius: 4
        rotation: -30
        color: Qt.rgba(1, 1, 1, 0.75)
    }

    Icon {
        anchors.centerIn: parent
        name: "moon"
        size: 14
        stroke: 2
        color: Theme.ink
        opacity: Shell.dnd ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
    }

    Rectangle {
        id: rec
        visible: Shell.recording
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: -2
        width: 9; height: 9
        radius: 4.5
        color: Theme.rose
        border.color: Theme.pearl
        border.width: 1.5

        SequentialAnimation on opacity {
            running: rec.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                Quickshell.execDetached(["rice", "choose"]);
                return;
            }
            const p = root.mapToItem(null, root.width / 2, root.height / 2);
            const screen = root.bar.screen;
            Shell.orbScreen = screen;
            Shell.orbCenter = Qt.point((screen.width - root.bar.width) / 2 + p.x, root.bar.margins.top + p.y);
            Shell.toggleLauncher();
        }
    }
}
