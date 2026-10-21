import QtQuick
import qs
import qs.common

// A level: a glass button for the icon (click to mute), a thin track with a
// teal line of light that follows the pointer, a glowing bead at its end,
// and the value in mono. Drag, click or scroll; above 1 the track marks
// where 100% is.
Item {
    id: root

    property string icon: "volume"
    property real value: 0
    property real max: 1
    property bool muted: false
    property bool available: true
    readonly property real shown: drag.pressed ? drag.preview : value
    readonly property real fraction: Math.max(0, Math.min(1, shown / max))

    signal moved(real value)
    signal iconClicked()

    implicitHeight: 32
    opacity: available ? 1 : 0.45

    Item {
        id: iconBox
        width: 32
        height: 32
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: iconMouse.containsMouse ? Theme.washHover : Theme.wash
            border.color: Theme.line
        }
        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 15
            color: root.muted ? Theme.inkDim : Theme.ink
        }
        MouseArea {
            id: iconMouse
            anchors.fill: parent
            enabled: root.available
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    Item {
        id: track
        anchors.left: iconBox.right
        anchors.leftMargin: 12
        anchors.right: valueLabel.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 14

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 2
            radius: 1
            color: Theme.line
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.fraction
            height: 2
            radius: 1
            color: root.muted ? Theme.inkDim : Theme.glow
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        // 100%, when the slider goes past it
        Rectangle {
            visible: root.max > 1
            x: parent.width / root.max - 0.5
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 10
            color: Theme.inkDim
            opacity: 0.6
        }
        Item {
            x: parent.width * root.fraction - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10
            Glow {
                anchors.centerIn: parent
                width: drag.pressed || drag.containsMouse ? 34 : 24; height: width
                color: root.muted ? Theme.inkDim : Theme.glow
                opacity: 0.7
            }
            Rectangle {
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                color: Theme.ink
            }
        }
        MouseArea {
            id: drag
            property real preview: 0
            anchors.fill: parent
            anchors.margins: -10
            enabled: root.available
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.max(0, Math.min(1, (x - 10) / track.width)) * root.max; }
            onPressed: mouse => { preview = at(mouse.x); root.moved(preview); }
            onPositionChanged: mouse => { if (pressed) { preview = at(mouse.x); root.moved(preview); } }
            onWheel: wheel => root.moved(Math.max(0, Math.min(root.max, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    Label {
        id: valueLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.shown * 100)
        font.family: Theme.fontMono
        size: 12
        color: root.muted ? Theme.inkDim : Theme.ink
    }
}
