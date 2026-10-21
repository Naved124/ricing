import QtQuick

// A strip of washi tape: pink and white diagonal stripes, a little see-through,
// stuck on at an angle (set `rotation`, ±11–14° looks right).
Item {
    id: root

    property color a: Theme.tapeA
    property color b: Theme.tapeB

    implicitWidth: 70
    implicitHeight: 22
    opacity: Theme.tapeOpacity
    antialiasing: true

    // a faint lift where the tape stands off the paper
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: -1
        color: Qt.alpha(Theme.soot, 0.08)
    }

    Item {
        anchors.fill: parent
        clip: true

        // 7 px stripes at 45°, wide enough to cover the strip once turned
        Row {
            anchors.centerIn: parent
            rotation: 45
            Repeater {
                model: Math.ceil((root.width + root.height) * 1.5 / 7) + 2
                delegate: Rectangle {
                    required property int index
                    width: 7
                    height: (root.width + root.height) * 1.5
                    color: index % 2 ? root.b : root.a
                }
            }
        }
    }
}
