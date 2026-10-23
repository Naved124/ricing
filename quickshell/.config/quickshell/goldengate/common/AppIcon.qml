import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

// An app's icon by its desktop id, class or icon name, MacTahoe's when it
// has one; without one, a rounded tile with the app's initial
Item {
    id: root
    property string app: ""
    property real implicitSize: 48
    readonly property var entry: app ? DesktopEntries.heuristicLookup(app) : null
    readonly property string path: app ? Quickshell.iconPath(entry && entry.icon ? entry.icon : app.toLowerCase(), true) : ""
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    IconImage {
        anchors.fill: parent
        visible: root.path !== ""
        source: root.path
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: parent.width * 0.08
        visible: root.path === ""
        radius: width * 0.22
        color: Theme.graphite
        Label {
            anchors.centerIn: parent
            text: ((root.entry && root.entry.name) || root.app.split(".").pop() || "?").charAt(0).toUpperCase()
            color: Theme.onAccent
            font.pixelSize: parent.height * 0.5
            strong: true
        }
    }
}
