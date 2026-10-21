pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common

// The desk: assets/wall.png (wall-dark.png at night), still, on the background layer of every
// monitor. Nothing moves, so it costs nothing once drawn. (For a monitor
// that isn't 16:9, run assets/gen.py --size WxH; until then it's cropped.)
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "paper-wallpaper"
    color: Theme.wall

    // the desk by day, and the same desk under the lamp, crossfaded by k
    Image {
        anchors.fill: parent
        source: "file://" + Theme.wallpaperLight
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        sourceSize: Qt.size(root.width, root.height)
        visible: Theme.k < 1
    }
    Image {
        anchors.fill: parent
        source: "file://" + Theme.wallpaperDark
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        sourceSize: Qt.size(root.width, root.height)
        opacity: Theme.k
        visible: Theme.k > 0
    }

    // the still frame the lock screen, the login greeter and the boot menu
    // use (system/install looks for ~/.cache/rice/<rice>/still.png)
    Process {
        running: root.screen === Quickshell.screens[0]
        command: ["sh", "-c", 'mkdir -p "$1" && cp -f "$2" "$1/still.png"', "sh",
            Quickshell.env("HOME") + "/.cache/rice/paper", Theme.wallpaper]
    }
}
