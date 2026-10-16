import QtQuick
import qs
import qs.common

// A level slider: an icon (click to mute), a pill track with an iridescent
// fill that follows the pointer, and the value. Drag, click or scroll.
Item {
    id: root

    property string icon: "volume"
    property real value: 0                 // 0..max (shown)
    property real max: 1                   // above 1 the track marks where 100% is
    property bool muted: false
    property bool available: true
    readonly property real shown: drag.pressed ? drag.preview : value
    readonly property real fraction: Math.max(0, Math.min(1, shown / max))

    signal moved(real value)
    signal iconClicked()

    implicitHeight: 34
    opacity: available ? 1 : 0.45

    Item {
        id: iconBox
        width: 34
        height: 34
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: iconMouse.containsMouse ? Theme.pearl : Theme.glassSoft
            border.color: Theme.hairline
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 16
            color: root.muted ? Theme.inkSoft : Theme.ink
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
        height: 12

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.shell
            border.color: Theme.hairline
        }
        Iridescent {
            height: parent.height
            width: Math.max(height, parent.width * root.fraction)
            radius: height / 2
            period: 9000
            opacity: root.muted ? 0.35 : 1
            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
        // where 100% sits when the slider goes beyond it
        Rectangle {
            visible: root.max > 1
            x: parent.width / root.max - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: parent.height + 6
            radius: 1
            color: Theme.inkSoft
            opacity: 0.5
        }
        // the knob: a small glossy pearl
        Pearl {
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.fraction - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: drag.pressed || drag.containsMouse ? 20 : 16
            height: width
            gloss: 0.9
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
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
        width: 40
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.shown * 100)
        font.family: Theme.fontDisplay
        size: 19
        color: root.muted ? Theme.inkSoft : Theme.ink
    }
}
