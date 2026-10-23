pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// The desktop picture, one per screen, under everything. A picture with a
// night twin (Settings.wallpaper.currentDark: name-dark.* beside
// name-light.*, macOS's "dynamic" style) crossfades with the mode.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "goldengate:wallpaper"
    color: Theme.underPage

    Picture {
        anchors.fill: parent
        source: Walls.day
    }
    Picture {
        anchors.fill: parent
        source: Walls.night
        visible: Walls.night !== ""
        opacity: Theme.k
    }

    // a right-click on the desktop: its menu (Change Wallpaper…, the widgets)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: m => {
            Shell.desktopMenuAt = Qt.point(m.x, m.y);
            if (Shell.open !== "desktopmenu") Shell.toggle("desktopmenu");
        }
    }

    component Picture: Image {
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Walls.fillMode
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
    }
}
