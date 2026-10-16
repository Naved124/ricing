import QtQuick
import Quickshell.Hyprland
import qs.common
import qs.services
import "../common/paper.js" as P

// "now: <the window's title>": the label in graphite, the title in ink,
// cut in the middle at 40 characters. Click it for the launcher.
Item {
    id: root

    required property var monitor
    readonly property var window: Hyprland.activeToplevel
    readonly property bool here: !!monitor?.focused && !!window
        && window.workspace?.id === monitor?.activeWorkspace?.id
    readonly property string title: here ? (window.title || window.lastIpcObject?.class || "") : ""

    implicitHeight: label.implicitHeight

    Row {
        id: label
        anchors.centerIn: parent
        spacing: 6

        Hand {
            text: "now:"
            color: Theme.graphite
        }
        Hand {
            text: root.title ? P.middle(root.title, 40) : "bare desk"
            color: Theme.ink
        }
    }

    MouseArea {
        anchors.centerIn: label
        width: label.width + 20
        height: label.height + 8
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.toggleLauncher("")
    }
}
