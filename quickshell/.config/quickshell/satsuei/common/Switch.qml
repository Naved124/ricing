import QtQuick

// The mock's switch: a 36 × 21 pill, the accent when on, its light knob
// sliding across with a little overshoot.
Rectangle {
    id: root

    property bool on: false
    signal toggled()

    width: 36
    height: 21
    radius: height / 2
    color: on ? Theme.accent : Theme.at(Theme.fg, 0.18)
    Behavior on color { ColorAnimation { duration: 250 } }

    Rectangle {
        x: root.on ? 18 : 3
        y: 3
        width: 15; height: 15
        radius: 7.5
        color: Theme.fg
        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 1.4, 0.5, 1, 1, 1] } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
