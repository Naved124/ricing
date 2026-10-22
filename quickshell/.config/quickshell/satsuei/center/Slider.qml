import QtQuick
import QtQuick.Effects
import qs.common

// A level, the mock's slider: an icon, an 8 px track filled with the accent
// up to the thumb (an 18 px light disc with a shadow), and the number in
// mono. Drag or click; the wheel steps by 5. `from`/`to` in the units shown.
Item {
    id: root

    property string icon: "volume"
    property real from: 0
    property real to: 100
    property real value: 50
    signal moved(real v)

    implicitHeight: 22

    Icon {
        id: ico
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        color: Theme.fg
    }
    Item {
        id: track
        anchors.left: ico.right
        anchors.leftMargin: 10
        anchors.right: out.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        readonly property real frac: Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: 4
            color: Theme.track
            Rectangle {
                width: parent.width * track.frac
                height: parent.height
                radius: 4
                color: Theme.accent
            }
        }
        RectangularShadow {
            anchors.fill: thumb
            radius: 9
            offset.y: 2
            blur: 8
            color: Theme.at(Theme.ink, 0.35)
        }
        Rectangle {
            id: thumb
            x: track.frac * (track.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 9
            color: Theme.fg
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function at(x) { return root.from + Math.max(0, Math.min(1, x / width)) * (root.to - root.from); }
            onPressed: mouse => root.moved(at(mouse.x))
            onPositionChanged: mouse => { if (pressed) root.moved(at(mouse.x)); }
            onWheel: wheel => root.moved(Math.max(root.from, Math.min(root.to, root.value + (wheel.angleDelta.y > 0 ? 5 : -5))))
        }
    }
    Label {
        id: out
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value)
        mono: true
        size: 11
        color: Theme.fgDim
    }
}
