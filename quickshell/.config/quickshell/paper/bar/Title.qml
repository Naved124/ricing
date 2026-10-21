import QtQuick
import qs.common
import qs.services

// "now: <the window's title>", just after the workspace numbers: the label
// in graphite, the title in ink. A title too long for the room it has slides
// past and comes round again (Marquee). Click it for the launcher.
Item {
    id: root

    required property var monitor
    // the focused window is on the focused monitor; other bars stay quiet
    readonly property string title: monitor?.focused ? (Hypr.activeTitle || Hypr.activeClass) : ""

    implicitWidth: now.implicitWidth + 6 + line.implicitWidth
    implicitHeight: 34

    Hand {
        id: now
        anchors.verticalCenter: parent.verticalCenter
        text: "now:"
        color: Theme.graphite
    }
    Marquee {
        id: line
        x: Math.round(now.implicitWidth + 6)
        width: Math.max(0, Math.round(root.width - x))
        height: root.height
        delegate: Hand {
            text: root.title || "bare desk"
            color: Theme.ink
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.toggleLauncher("")
    }
}
